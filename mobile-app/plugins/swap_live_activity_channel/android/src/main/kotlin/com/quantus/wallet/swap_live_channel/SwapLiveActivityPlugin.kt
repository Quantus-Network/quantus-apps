package com.quantus.wallet.swap_live_channel

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Set from the app before any engine starts. The background engine has no
/// activity, so the app handles the call with the application context.
object SwapLiveActivityHost {
    var handle: ((Context, MethodCall, MethodChannel.Result) -> Unit)? = null
}

/// Registers the swap card channel on each Flutter engine, including the one
/// Firebase starts to deliver a background data message.
class SwapLiveActivityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.quantus/swap_live_activity")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val handle = SwapLiveActivityHost.handle
        if (handle == null) {
            result.error("unavailable", "Swap live activity is not ready", null)
        } else {
            handle(context, call, result)
        }
    }
}
