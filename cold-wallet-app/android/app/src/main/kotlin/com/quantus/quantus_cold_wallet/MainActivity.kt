package com.quantus.quantus_cold_wallet

import android.os.Bundle
import com.quantus.sealedsecret.SealedSecretStore
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SealedSecretStore.bind(this)
    }
}
