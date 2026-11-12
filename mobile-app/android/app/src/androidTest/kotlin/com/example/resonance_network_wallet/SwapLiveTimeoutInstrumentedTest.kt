package com.example.resonance_network_wallet

import android.os.Build
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/// The system removes a finished swap card on its own. A swap still moving keeps its card.
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = Build.VERSION_CODES.O)
class SwapLiveTimeoutInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun finishedCardHasTimeout_inProgressDoesNot() {
        val now = System.currentTimeMillis()

        val swapped = SwapLiveNotifications.build(context, card("swapped", null, now, holdsProcess = false))
        assertWithin(SWAP_LIVE_SWAPPED_WINDOW_MS, swapped.timeoutAfter)

        val refunded = SwapLiveNotifications.build(context, card("failed", "refunded", now, holdsProcess = false))
        assertWithin(SWAP_LIVE_FAILED_WINDOW_MS, refunded.timeoutAfter)

        val incomplete = SwapLiveNotifications.build(context, card("failed", "incomplete", now, holdsProcess = false))
        assertEquals(0L, incomplete.timeoutAfter)

        val settling = SwapLiveNotifications.build(context, card("settling", null, now, holdsProcess = true))
        assertEquals(0L, settling.timeoutAfter)
    }

    private fun assertWithin(window: Long, timeout: Long) {
        // The card is built a moment after `now`, so a little of the window is already gone.
        assertTrue("timeout $timeout for window $window", timeout in (window - 60_000L)..window)
    }

    private fun card(phase: String, failure: String?, updatedAt: Long, holdsProcess: Boolean): JSONObject =
        JSONObject()
            .put("key", "swap-a")
            .put("phase", phase)
            .put("failure", failure ?: JSONObject.NULL)
            .put("brand", "Quantus")
            .put("idleBrand", "Quantus")
            .put("headline", "Swap")
            .put("progress", if (holdsProcess) 0.75 else 1.0)
            .put("showProgress", holdsProcess)
            .put("holdsProcess", holdsProcess)
            .put("updatedAt", updatedAt)
            .put("staleAt", updatedAt + 120_000L)
            .put("endsAt", JSONObject.NULL)
}
