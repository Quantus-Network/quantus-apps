package com.example.resonance_network_wallet

import android.widget.RemoteViews
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.AndroidJUnit4
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/// Inflates the swap card the way SystemUI does. [RemoteViews.apply] rejects any widget
/// that is not annotated [RemoteViews.RemoteView].
@RunWith(AndroidJUnit4::class)
class SwapLiveActivityInflationTest {
    @Test
    fun remoteViewsApplyInflatesSwapLiveLayout() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val views = RemoteViews(context.packageName, R.layout.swap_live_activity)
        val root = views.apply(context, null)
        assertNotNull(root.findViewById(R.id.swap_live_tick_25))
        assertNotNull(root.findViewById(R.id.swap_live_tick_50))
        assertNotNull(root.findViewById(R.id.swap_live_tick_75))
    }
}
