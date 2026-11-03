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
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/// The swap card on the lock screen, and the status-bar progress on Android 16.
object SwapLiveNotifications {
    const val NOTIFICATION_ID = 71041
    const val CHANNEL_ID = "swap_live_activity"
    const val EXTRA_PAYLOAD = "payload"
    const val ACTION_STALE = "com.quantus.wallet.SWAP_LIVE_STALE"
    const val ACTION_DISMISSED = "com.quantus.wallet.SWAP_LIVE_DISMISSED"

    private const val PREFS = "swap_live_activity"
    private const val PREF_PAYLOAD = "payload"
    private const val METHOD_CHANNEL = "app.quantus/swap_live_activity"
    private const val EVENT_CHANNEL = "app.quantus/swap_live_activity_events"

    private var events: EventChannel.EventSink? = null
    private var pendingDismiss = false
    private var ignoreDelete = false

    fun bind(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Expected the swap card payload", null)
                    } else {
                        show(context.applicationContext, jsonOf(args), stale = false)
                        result.success(null)
                    }
                }
                "end" -> {
                    end(context.applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
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

    fun show(context: Context, json: JSONObject, stale: Boolean) {
        ignoreDelete = false
        val card = if (stale) json.put("stale", true) else json
        ensureChannel(context, card.optString("channelName", "Swap progress"))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(PREF_PAYLOAD, card.toString()).apply()
        val holds = card.optBoolean("holdsProcess") && !stale
        val launch = Intent(context, SwapLiveActivityService::class.java).putExtra(EXTRA_PAYLOAD, card.toString())
        if (holds) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(launch)
            } else {
                context.startService(launch)
            }
        } else if (!stale) {
            context.startService(launch)
        } else {
            // The alarm can fire with the app suspended, which may not start a service.
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, build(context, card))
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

    fun onDeleted() {
        if (ignoreDelete) {
            ignoreDelete = false
            return
        }
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
        val staleAt = json.optLong("staleAt", 0L)
        if (staleAt <= 0L) return
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, staleAt, broadcast(context, ACTION_STALE, 1))
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
            SwapLiveNotifications.ACTION_DISMISSED -> SwapLiveNotifications.onDeleted()
        }
    }
}
