package com.example.resonance_network_wallet

import android.app.AlarmManager
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
    private var ignoreDelete = false

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
                        sink.success(mapOf("type" to "dismissed"))
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
            else -> result.notImplemented()
        }
    }

    /// The stored card, so a push can tell a matching live card from a dismissed one.
    fun card(context: Context): Map<String, String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "key" to storedKey(prefs).orEmpty(),
            "dismissedKey" to prefs.getString(PREF_DISMISSED, null).orEmpty(),
        )
    }

    /// Draws [data] when it is a `swap_live_activity` update for the card on screen.
    /// Same rules as `swapLiveActivityPushUpdate`: matching key, and not dismissed.
    fun apply(context: Context, data: Map<*, *>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val update = swapLivePushUpdate(data, storedKey(prefs), prefs.getString(PREF_DISMISSED, null)) ?: return
        show(context, update, stale = false)
    }

    fun show(context: Context, json: JSONObject, stale: Boolean) {
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
        } else {
            sink.success(mapOf("type" to "dismissed"))
        }
    }

    fun build(context: Context, json: JSONObject): Notification {
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

    private fun storedKey(prefs: android.content.SharedPreferences): String? {
        val raw = prefs.getString(PREF_PAYLOAD, null) ?: return null
        val key = runCatching { JSONObject(raw).optString("key") }.getOrNull()
        return key?.takeIf { it.isNotEmpty() }
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

internal fun swapLivePushUpdate(data: Map<*, *>, shownKey: String?, dismissedKey: String?): JSONObject? {
    if (data["type"]?.toString() != SwapLiveNotifications.MESSAGE_TYPE) return null
    val fields = pushFields(data)
    val key = fields["key"]?.toString().orEmpty()
    val phase = fields["phase"]?.toString().orEmpty()
    if (key.isEmpty() || phase.isEmpty() || shownKey != key || dismissedKey == key) return null
    val json = JSONObject()
    for (name in pushStringFields) json.put(name, fields[name]?.toString() ?: "")
    for (name in pushValueFields) json.put(name, pushValue(name, fields[name]))
    return json
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
