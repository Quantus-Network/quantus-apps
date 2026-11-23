package com.example.resonance_network_wallet

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import com.quantus.wallet.swap_live_channel.SwapLiveActivityHost

/// Connects the background engine's method channel to the swap card before a
/// push can arrive. Content providers run when the process starts, which for a
/// data message is before the background isolate.
class SwapLiveActivityInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        SwapLiveActivityHost.handle = { context, call, result ->
            SwapLiveNotifications.handle(context, call, result)
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
