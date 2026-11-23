package com.example.resonance_network_wallet

import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import android.widget.TextView
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
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

    /// The widest strings `formatCompactAmount` produces and the longest chain name, on a 360dp phone's card (255dp wide).
    @Test
    fun longestCompactAmountsFitTheirColumns() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val views = RemoteViews(context.packageName, R.layout.swap_live_activity)
        views.setTextViewText(R.id.swap_live_from_amount, "<0.0001")
        views.setTextViewText(R.id.swap_live_from_symbol, "WBTC")
        views.setTextViewText(R.id.swap_live_to_amount, "123.4K")
        views.setTextViewText(R.id.swap_live_to_symbol, "USDC")
        views.setTextViewText(R.id.swap_live_chain_value, "Robinhood Chain")
        val root = views.apply(context, null)

        val width = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 255f, context.resources.displayMetrics)
        // Auto-size runs in onLayout and requests another pass, as the next frame would.
        repeat(3) {
            root.measure(
                View.MeasureSpec.makeMeasureSpec(width.toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            root.layout(0, 0, root.measuredWidth, root.measuredHeight)
        }
        assertFalse("layout did not settle", root.isLayoutRequested)

        for (id in listOf(
            R.id.swap_live_from_amount,
            R.id.swap_live_from_symbol,
            R.id.swap_live_to_amount,
            R.id.swap_live_to_symbol,
        )) {
            val text = root.findViewById<TextView>(id)
            val name = context.resources.getResourceEntryName(id)
            assertEquals("$name wraps", 1, text.lineCount)
            val drawn = text.paint.measureText(text.text.toString()) + text.totalPaddingLeft + text.totalPaddingRight
            assertTrue("$name is clipped: ${text.width}px for ${drawn}px of text", text.width >= drawn)
        }
        // A chain name may shrink and end in an ellipsis, but stays on one line.
        assertEquals("swap_live_chain_value wraps", 1, root.findViewById<TextView>(R.id.swap_live_chain_value).lineCount)
    }
}
