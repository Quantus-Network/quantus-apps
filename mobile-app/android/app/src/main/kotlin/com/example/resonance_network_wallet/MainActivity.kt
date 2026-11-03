package com.example.resonance_network_wallet

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SwapLiveNotifications.bind(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
