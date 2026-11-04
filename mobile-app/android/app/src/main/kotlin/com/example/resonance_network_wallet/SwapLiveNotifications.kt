package com.example.resonance_network_wallet

import android.app.AlarmManager
import androidx.annotation.RequiresApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/// The swap card on the lock screen, and the status-bar progress on Android 16.
object SwapLiveNotifications {
    const val NOTIFICATION_ID = 71041
    const val CHANNEL_ID = "swap_live_activity"
    const val EXTRA_PAYLOAD = "payload"
    const val ACTION_STALE = "com.quantus.wallet.SWAP_LIVE_STALE"
    const val ACTION_DISMISSED = "com.quantus.wallet.SWAP_LIVE_DISMISSED"
    const val MESSAGE_TYPE = "swap_live_activity"

    private const val PREFS = "swap_live_activity"
    private const val PREF_PAYLOAD = "payload"
    private const val PREF_DISMISSED = "dismissed_key"
    private const val TAG = "SwapLive"
    private const val METHOD_CHANNEL = "app.quantus/swap_live_activity"
    private const val EVENT_CHANNEL = "app.quantus/swap_live_activity_events"

    private var events: EventChannel.EventSink? = null
    private var pendingDismiss = false
    private var pendingDismissKey: String? = null
    private var ignoreDelete = false

    /// Serializes push read-compare-write. The Dart path and [SwapLivePushReceiver]
    /// both deliver FCM, and the two can be interleaved on the main thread.
    private val revisionLock = Any()

    fun bind(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            handle(context, call, result)
        }
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    if (pendingDismiss) {
                        pendingDismiss = false
                        val key = pendingDismissKey
                        pendingDismissKey = null
                        sink.success(swapLiveDismissEvent(key))
                    }
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )
    }

    /// Method channel entry used by the activity engine and, through
    /// [com.quantus.wallet.swap_live_channel.SwapLiveActivityHost], by the
    /// background engine that receives FCM after the UI is gone.
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val app = context.applicationContext
        when (call.method) {
            "show" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "Expected the swap card payload", null)
                } else {
                    show(app, jsonOf(args), stale = false)
                    result.success(null)
                }
            }
            "end" -> {
                end(app)
                result.success(null)
            }
            "card" -> result.success(card(app))
            "apply" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "Expected the swap push payload", null)
                } else {
                    apply(app, args)
                    result.success(null)
                }
            }
            "replace" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "Expected the swap push payload", null)
                } else {
                    replace(app, jsonOf(args))
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /// The stored card, so a push can tell a matching live card from a dismissed one.
    fun card(context: Context): Map<String, Any> {
        val stored = synchronized(revisionLock) {
            storedSwapCard(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE))
        }
        val card = HashMap<String, Any>()
        card["key"] = stored.key.orEmpty()
        card["dismissedKey"] = stored.dismissedKey.orEmpty()
        card["phase"] = stored.phase.orEmpty()
        stored.failure?.let { card["failure"] = it }
        stored.updatedAt?.let { card["updatedAt"] = it }
        return card
    }

    /// Draws [data] when it is a `swap_live_activity` update for the card on screen.
    /// Same rules as `swapLiveActivityPushUpdate`.
    fun apply(context: Context, data: Map<*, *>) {
        commitPush(context, data)
    }

    /// Parsed card from the Dart path. Compared again under [revisionLock] so it
    /// cannot replace a revision that landed after Dart read [card].
    fun replace(context: Context, json: JSONObject) {
        commitPush(context, pushData(json))
    }

    private fun commitPush(context: Context, data: Map<*, *>) {
        synchronized(revisionLock) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val stored = storedSwapCard(prefs)
            val update = swapLivePushUpdate(data, stored.key, stored.dismissedKey, stored.revision) ?: return
            show(context, update, stale = false)
        }
    }

    private fun pushData(json: JSONObject): Map<String, Any?> {
        val data = HashMap<String, Any?>()
        data["type"] = MESSAGE_TYPE
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            data[key] = if (json.isNull(key)) null else json.get(key)
        }
        return data
    }

    fun show(context: Context, json: JSONObject, stale: Boolean) {
        synchronized(revisionLock) {
            // A poll can arrive after a completion push. The same order that
            // guards replace applies here, or the poll starts the foreground
            // service again for a swap that has already finished. A dismissal
            // persisted while no listener was attached is refused here too.
            if (!acceptsLocalWrite(context, json)) return
            ignoreDelete = false
            val card = if (stale) json.put("stale", true) else json
            ensureChannel(context, card.optString("channelName", "Swap progress"))
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val editor = prefs.edit().putString(PREF_PAYLOAD, card.toString())
            val dismissed = prefs.getString(PREF_DISMISSED, null)
            val key = card.optString("key")
            if (!dismissed.isNullOrEmpty() && dismissed != key) editor.remove(PREF_DISMISSED)
            editor.apply()
            val holds = card.optBoolean("holdsProcess") && !stale
            if (stale) {
                // The alarm can fire with the app suspended, which may not start a service.
                context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, build(context, card))
            } else {
                launch(context, card, holds)
            }
            if (!stale) scheduleStale(context, card)
        }
    }

    /// Same-swap polling writes use the push revision rules. A different key is a new swap.
    private fun acceptsLocalWrite(context: Context, json: JSONObject): Boolean {
        val stored = storedSwapCard(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE))
        return swapLiveLocalWriteAllowed(
            incomingKey = json.optString("key"),
            incomingUpdatedAt = if (json.isNull("updatedAt")) null else epochOf(json.opt("updatedAt")),
            incomingPhase = json.optString("phase"),
            incomingFailure = if (json.isNull("failure")) null else textOrNull(json.opt("failure")),
            storedKey = stored.key,
            stored = stored.revision,
            dismissedKey = stored.dismissedKey,
        )
    }

    fun showStale(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(PREF_PAYLOAD, null) ?: return
        show(context, JSONObject(raw), stale = true)
    }

    fun end(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.contains(PREF_PAYLOAD)) ignoreDelete = true
        cancelStale(context)
        prefs.edit().remove(PREF_PAYLOAD).apply()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(NOTIFICATION_ID)
        context.stopService(Intent(context, SwapLiveActivityService::class.java))
    }

    fun onDeleted(context: Context) {
        if (ignoreDelete) {
            ignoreDelete = false
            return
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = storedKey(prefs)
        if (!key.isNullOrEmpty()) prefs.edit().putString(PREF_DISMISSED, key).apply()
        cancelStale(context)
        val sink = events
        if (sink == null) {
            pendingDismiss = true
            pendingDismissKey = key
        } else {
            sink.success(swapLiveDismissEvent(key))
        }
    }

    fun build(context: Context, json: JSONObject): Notification {
        if (Build.VERSION.SDK_INT >= 36 && shouldPostLiveUpdate(context, json)) {
            return buildLiveUpdate(context, json)
        }
        return buildCustom(context, json)
    }

    /// A standard progress notification that meets the Live Update rules.
    /// Custom content views are intentionally absent: they disqualify promotion.
    @RequiresApi(36)
    private fun buildLiveUpdate(context: Context, json: JSONObject): Notification {
        val builder = Notification.Builder(context, CHANNEL_ID)
        builder
            .setSmallIcon(R.drawable.ic_swap_live)
            .setContentTitle(json.optString("brand"))
            .setContentText(json.optString("headline"))
            .setColor(0xFFFF6B35.toInt())
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setContentIntent(openApp(context))
            .setDeleteIntent(broadcast(context, ACTION_DISMISSED, 2))
            .setStyle(Notification.ProgressStyle().setProgress((json.optDouble("progress") * 100).toInt()))
            .addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
        swapPair(json)?.let(builder::setSubText)
        return builder.build()
    }

    private fun shouldPostLiveUpdate(context: Context, json: JSONObject): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        val stale = json.optBoolean("stale")
        val ongoing = json.optBoolean("holdsProcess") && !stale
        val showProgress = json.optBoolean("showProgress") && !stale
        val hasTitle = json.optString("brand").isNotEmpty()
        if (Build.VERSION.SDK_INT_FULL < LIVE_UPDATE_MIN_SDK_FULL || !ongoing || !showProgress || !hasTitle) {
            return false
        }
        return liveUpdateEligible(
            sdkInt = Build.VERSION.SDK_INT,
            sdkFull = Build.VERSION.SDK_INT_FULL,
            authorized = context.getSystemService(NotificationManager::class.java).canPostPromotedNotifications(),
            ongoing = ongoing,
            showProgress = showProgress,
            hasTitle = hasTitle,
        )
    }

    private fun swapPair(json: JSONObject): String? {
        val fromAmount = json.optString("fromAmount")
        val fromSymbol = json.optString("fromSymbol")
        val toAmount = json.optString("toAmount")
        val toSymbol = json.optString("toSymbol")
        if (fromAmount.isEmpty() && fromSymbol.isEmpty() && toAmount.isEmpty() && toSymbol.isEmpty()) return null
        return "$fromAmount $fromSymbol → $toAmount $toSymbol".replace(Regex("\\s+"), " ").trim()
    }

    private fun buildCustom(context: Context, json: JSONObject): Notification {
        val views = RemoteViews(context.packageName, R.layout.swap_live_activity)
        val stale = json.optBoolean("stale")
        val brand = if (stale) json.optString("idleBrand") else json.optString("brand")
        views.setTextViewText(R.id.swap_live_brand, brand)
        views.setTextViewText(R.id.swap_live_headline, json.optString("headline"))
        views.setTextViewText(R.id.swap_live_from_label, json.optString("fromLabel"))
        views.setTextViewText(R.id.swap_live_to_label, json.optString("toLabel"))
        views.setTextViewText(R.id.swap_live_chain_label, json.optString("chainLabel"))
        views.setTextViewText(R.id.swap_live_chain_value, json.optString("chain"))
        views.setTextViewText(R.id.swap_live_from_amount, json.optString("fromAmount"))
        views.setTextViewText(R.id.swap_live_from_symbol, json.optString("fromSymbol"))
        views.setTextViewText(R.id.swap_live_to_amount, json.optString("toAmount"))
        views.setTextViewText(R.id.swap_live_to_symbol, json.optString("toSymbol"))
        bindTiming(views, json, stale)
        val showProgress = json.optBoolean("showProgress") && !stale
        views.setViewVisibility(R.id.swap_live_progress, if (showProgress) View.VISIBLE else View.GONE)
        if (showProgress) {
            views.setProgressBar(R.id.swap_live_progress, 1000, (json.optDouble("progress") * 1000).toInt(), false)
        }
        views.setTextViewText(R.id.swap_live_open, json.optString("openToCheck"))
        views.setViewVisibility(R.id.swap_live_open, if (stale) View.VISIBLE else View.GONE)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_swap_live)
            .setContentTitle(brand)
            .setContentText(json.optString("headline"))
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setColor(0xFFFF6B35.toInt())
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(json.optBoolean("holdsProcess") && !stale)
            .setContentIntent(openApp(context))
            .setDeleteIntent(broadcast(context, ACTION_DISMISSED, 2))
        if (Build.VERSION.SDK_INT >= 36 && showProgress) {
            builder.setStyle(Notification.ProgressStyle().setProgress((json.optDouble("progress") * 100).toInt()))
        }
        return builder.build()
    }

    private fun bindTiming(views: RemoteViews, json: JSONObject, stale: Boolean) {
        val now = System.currentTimeMillis()
        val elapsed = SystemClock.elapsedRealtime()
        if (stale) {
            views.setViewVisibility(R.id.swap_live_eta, View.GONE)
            views.setViewVisibility(R.id.swap_live_ago, View.VISIBLE)
            val updatedAt = json.optLong("updatedAt", now)
            views.setChronometer(R.id.swap_live_ago_time, elapsed - (now - updatedAt), null, true)
            views.setTextViewText(R.id.swap_live_ago_label, json.optString("agoLabel"))
            return
        }
        views.setViewVisibility(R.id.swap_live_ago, View.GONE)
        if (json.isNull("endsAt")) {
            views.setViewVisibility(R.id.swap_live_eta, View.GONE)
            return
        }
        val endsAt = json.optLong("endsAt")
        views.setViewVisibility(R.id.swap_live_eta, View.VISIBLE)
        views.setChronometer(R.id.swap_live_eta, elapsed + (endsAt - now), "~%s", true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.setChronometerCountDown(R.id.swap_live_eta, true)
        }
    }

    private fun ensureChannel(context: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_HIGH)
        channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        channel.setSound(null, null)
        manager.createNotificationChannel(channel)
    }

    private fun scheduleStale(context: Context, json: JSONObject) {
        val staleAt = if (json.isNull("staleAt")) 0L else json.optLong("staleAt", 0L)
        if (staleAt <= 0L) {
            cancelStale(context)
            return
        }
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, staleAt, broadcast(context, ACTION_STALE, 1))
    }

    private fun launch(context: Context, card: JSONObject, holds: Boolean) {
        val launch = Intent(context, SwapLiveActivityService::class.java).putExtra(EXTRA_PAYLOAD, card.toString())
        try {
            if (holds && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(launch)
            } else {
                context.startService(launch)
            }
        } catch (error: IllegalStateException) {
            // A push can arrive while the process is backgrounded and not allowed to start a service.
            Log.w(TAG, "Updating the swap card without a service", error)
            context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, build(context, card))
        }
    }

    private class StoredSwapCard(
        val key: String?,
        val dismissedKey: String?,
        val updatedAt: Long?,
        val phase: String?,
        val failure: String?,
    ) {
        val revision = SwapLiveCardRevision(updatedAt, phase, failure)
    }

    private fun storedKey(prefs: android.content.SharedPreferences): String? = storedSwapCard(prefs).key

    private fun storedSwapCard(prefs: android.content.SharedPreferences): StoredSwapCard {
        val dismissed = prefs.getString(PREF_DISMISSED, null)
        val raw = prefs.getString(PREF_PAYLOAD, null) ?: return StoredSwapCard(null, dismissed, null, null, null)
        val json = runCatching { JSONObject(raw) }.getOrNull()
        if (json == null) return StoredSwapCard(null, dismissed, null, null, null)
        return StoredSwapCard(
            json.optString("key").takeIf { it.isNotEmpty() },
            dismissed,
            if (json.isNull("updatedAt")) null else epochOf(json.opt("updatedAt")),
            json.optString("phase").takeIf { it.isNotEmpty() },
            if (json.isNull("failure")) null else textOrNull(json.opt("failure")),
        )
    }

    private fun cancelStale(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.cancel(broadcast(context, ACTION_STALE, 1))
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("quantus://swap")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context, 0, intent, pendingFlags())
    }

    private fun broadcast(context: Context, action: String, request: Int): PendingIntent {
        val intent = Intent(context, SwapLiveActivityReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(context, request, intent, pendingFlags())
    }

    private fun pendingFlags(): Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun jsonOf(args: Map<*, *>): JSONObject {
        val json = JSONObject()
        for ((key, value) in args) {
            if (key is String) json.put(key, value ?: JSONObject.NULL)
        }
        return json
    }
}

/// Holds the process while a swap is still moving, so status polls keep running
/// with the screen off. A finished card is a normal notification and the service stops.
class SwapLiveActivityService : Service() {
    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val raw = intent?.getStringExtra(SwapLiveNotifications.EXTRA_PAYLOAD)
        if (raw == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val json = JSONObject(raw)
        val notification = SwapLiveNotifications.build(this, json)
        val holds = json.optBoolean("holdsProcess") && !json.optBoolean("stale")
        if (holds) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    SwapLiveNotifications.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(SwapLiveNotifications.NOTIFICATION_ID, notification)
            }
        } else {
            getSystemService(NotificationManager::class.java).notify(SwapLiveNotifications.NOTIFICATION_ID, notification)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    stopForeground(STOP_FOREGROUND_DETACH)
                } catch (_: IllegalArgumentException) {
                    // The card was never a foreground notification.
                }
            }
            stopSelf()
        }
        return START_NOT_STICKY
    }
}

class SwapLiveActivityReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            SwapLiveNotifications.ACTION_STALE -> SwapLiveNotifications.showStale(context)
            SwapLiveNotifications.ACTION_DISMISSED -> SwapLiveNotifications.onDeleted(context)
        }
    }
}

/// FCM data messages for the swap card. Runs when the process is started for a
/// push, including after the UI and its method channel are gone.
class SwapLivePushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return
        val extras = intent.extras ?: return
        val data = fcmData(extras)
        if (data["type"] != SwapLiveNotifications.MESSAGE_TYPE) return
        SwapLiveNotifications.apply(context.applicationContext, data)
    }
}

/// Data fields of an FCM message. Play Services puts them on the broadcast extras
/// next to its own `google.` and `gcm.` keys.
private fun fcmData(extras: Bundle): Map<String, String> {
    val data = HashMap<String, String>()
    for (key in extras.keySet()) {
        if (key.startsWith("google.") || key.startsWith("gcm.")) continue
        val value = extras.get(key)
        if (value is String) data[key] = value
    }
    return data
}

/// Keep in step with `swapLiveActivityPushUpdate`. A push updates only the card
/// already on screen for the same swap, and never one the user dismissed.
/// An older revision is dropped, and a finished card does not return to in progress.

internal data class SwapLiveCardRevision(
    val updatedAt: Long?,
    val phase: String?,
    val failure: String?,
)

/// Order for an FCM data message. Incomplete deposits stay open.
internal fun swapLiveRevisionAllows(
    incomingUpdatedAt: Long?,
    incomingPhase: String,
    incomingFailure: String?,
    stored: SwapLiveCardRevision,
): Boolean {
    if (incomingUpdatedAt == null) return false
    val storedAt = stored.updatedAt
    if (storedAt != null && incomingUpdatedAt < storedAt) return false
    val finished = swapLiveTerminal(stored.phase, stored.failure)
    return !finished || swapLiveTerminal(incomingPhase, incomingFailure)
}

internal fun swapLiveTerminal(phase: String?, failure: String?): Boolean {
    if (phase == "swapped") return true
    return phase == "failed" && failure != "incomplete"
}

/// A local write may start a card, or replace one with a different swap.
/// The swap already on screen follows [swapLiveRevisionAllows]. The swap the
/// user dismissed stays dismissed until a different swap starts.
internal fun swapLiveLocalWriteAllowed(
    incomingKey: String,
    incomingUpdatedAt: Long?,
    incomingPhase: String,
    incomingFailure: String?,
    storedKey: String?,
    stored: SwapLiveCardRevision,
    dismissedKey: String? = null,
): Boolean {
    if (incomingKey.isNotEmpty() && dismissedKey == incomingKey) return false
    if (storedKey.isNullOrEmpty()) return true
    if (incomingKey.isNotEmpty() && incomingKey != storedKey) return true
    return swapLiveRevisionAllows(incomingUpdatedAt, incomingPhase, incomingFailure, stored)
}

/// Dismissal signal for the Dart controller. [key] lets a new controller
/// record the swap before it has shown a card of its own.
internal fun swapLiveDismissEvent(key: String?): Map<String, String> {
    if (key.isNullOrEmpty()) return mapOf("type" to "dismissed")
    return mapOf("type" to "dismissed", "key" to key)
}

private val pushStringFields = listOf(
    "phase",
    "headline",
    "brand",
    "idleBrand",
    "fromAmount",
    "fromSymbol",
    "toAmount",
    "toSymbol",
    "chain",
    "fromLabel",
    "toLabel",
    "chainLabel",
    "openToCheck",
    "agoLabel",
    "key",
    "channelName",
)

private val pushValueFields = listOf("failure", "progress", "showProgress", "endsAt", "updatedAt", "staleAt", "holdsProcess")

internal fun swapLivePushFields(
    data: Map<*, *>,
    shownKey: String?,
    dismissedKey: String?,
    stored: SwapLiveCardRevision,
): Map<String, Any?>? {
    if (data["type"]?.toString() != SwapLiveNotifications.MESSAGE_TYPE) return null
    val fields = pushFields(data)
    val key = fields["key"]?.toString().orEmpty()
    val phase = fields["phase"]?.toString().orEmpty()
    if (key.isEmpty() || phase.isEmpty() || shownKey != key || dismissedKey == key) return null
    val allowed = swapLiveRevisionAllows(epochOf(fields["updatedAt"]), phase, textOrNull(fields["failure"]), stored)
    if (!allowed) return null
    return fields
}

internal fun swapLivePushUpdate(
    data: Map<*, *>,
    shownKey: String?,
    dismissedKey: String?,
    stored: SwapLiveCardRevision,
): JSONObject? {
    val fields = swapLivePushFields(data, shownKey, dismissedKey, stored) ?: return null
    val json = JSONObject()
    for (name in pushStringFields) json.put(name, fields[name]?.toString() ?: "")
    for (name in pushValueFields) json.put(name, pushValue(name, fields[name]))
    return json
}

private fun epochOf(value: Any?): Long? {
    if (value == null) return null
    if (value is Number) return value.toLong()
    val text = value as? String ?: return null
    if (text.isEmpty() || text == "null") return null
    return text.toLongOrNull()
}

private fun textOrNull(value: Any?): String? {
    if (value == null) return null
    val text = value.toString()
    if (text.isEmpty() || text == "null") return null
    return text
}

private fun pushFields(data: Map<*, *>): Map<String, Any?> {
    val nested = data["content_state"]
    val source = when (nested) {
        is Map<*, *> -> nested
        is String -> runCatching { JSONObject(nested) }.getOrNull()?.let { json ->
            json.keys().asSequence().associateWith { key -> if (json.isNull(key)) null else json.opt(key) }
        }
        else -> null
    } ?: data
    return source.entries.mapNotNull { (key, value) -> if (key is String) key to value else null }.toMap()
}

/// API 36.1, the first release that promotes an ongoing notification.
internal const val LIVE_UPDATE_MIN_SDK_FULL = 3_600_001

/// Value of Notification.EXTRA_REQUEST_PROMOTED_ONGOING. That constant is not in the API 36 SDK.
internal const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

/// Whether this card can be posted as a Live Update.
///
/// Promotion starts at API 36.1. The card has to be ongoing, show progress, and
/// have a title, and the user has to still allow promoted notifications.
/// Custom RemoteViews cannot be promoted, so that card stays the fallback.
internal fun liveUpdateEligible(
    sdkInt: Int,
    sdkFull: Int,
    authorized: Boolean,
    ongoing: Boolean,
    showProgress: Boolean,
    hasTitle: Boolean,
): Boolean {
    if (sdkInt < 36 || sdkFull < LIVE_UPDATE_MIN_SDK_FULL) return false
    return authorized && ongoing && showProgress && hasTitle
}

private fun pushValue(name: String, value: Any?): Any {
    if (value == null) return JSONObject.NULL
    val text = value as? String
    return when (name) {
        "showProgress", "holdsProcess" -> when (value) {
            is Boolean -> value
            is String -> value == "true"
            is Number -> value.toInt() != 0
            else -> false
        }
        "progress" -> when (value) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: 0.0
            else -> 0.0
        }
        "endsAt", "updatedAt", "staleAt" -> when {
            text != null && (text.isEmpty() || text == "null") -> JSONObject.NULL
            value is Number -> value.toLong()
            text != null -> text.toLongOrNull() ?: JSONObject.NULL
            else -> JSONObject.NULL
        }
        "failure" -> when {
            text != null && (text.isEmpty() || text == "null") -> JSONObject.NULL
            else -> value
        }
        else -> value
    }
}
