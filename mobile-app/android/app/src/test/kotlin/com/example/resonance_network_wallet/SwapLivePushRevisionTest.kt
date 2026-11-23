package com.example.resonance_network_wallet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SwapLivePushRevisionTest {
    private val shownKey = "qzdeposit|1"

    @Test
    fun olderSettlingDoesNotReplaceSwapped() {
        assertNull(update(settling(1000), stored(2000, "swapped", null)))
    }

    @Test
    fun newerSettlingDoesNotReopenSwapped() {
        assertNull(update(settling(3000), stored(2000, "swapped", null)))
    }

    @Test
    fun newerSwappedReplacesSettling() {
        val card = update(swapped(2000), stored(1000, "settling", null))
        assertEquals("swapped", card!!["phase"])
        assertEquals(false, card["holdsProcess"])
    }

    @Test
    fun aNewerFinishedUpdateStillApplies() {
        val card = update(swapped(3000), stored(2000, "swapped", null))
        assertEquals("swapped", card!!["phase"])
    }

    @Test
    fun theSameRevisionStillApplies() {
        val card = update(settling(2000), stored(2000, "settling", null))
        assertEquals("settling", card!!["phase"])
    }

    @Test
    fun incompleteDepositStillMovesForward() {
        val card = update(settling(2000), stored(1000, "failed", "incomplete"))
        assertEquals("settling", card!!["phase"])
        assertEquals(true, card["holdsProcess"])
    }

    @Test
    fun refundedCardDoesNotReturnToSettling() {
        assertNull(update(settling(3000), stored(2000, "failed", "refunded")))
    }

    @Test
    fun aDismissedSwapIsNotShownAgain() {
        assertFalse(localShow(shownKey, 4000, "settling", null, shownKey, stored(1000, "settling", null), shownKey))
    }

    @Test
    fun aDismissedSwapIsNotShownWhenThePayloadIsGone() {
        assertFalse(localShow(shownKey, 4000, "settling", null, null, stored(1000, "settling", null), shownKey))
    }

    @Test
    fun aDifferentSwapStillStartsAfterADismissal() {
        assertTrue(localShow("other|2", 1000, "settling", null, shownKey, stored(1000, "settling", null), shownKey))
    }

    @Test
    fun dismissEventCarriesTheSwapKey() {
        assertEquals(mapOf("type" to "dismissed", "key" to shownKey), swapLiveDismissEvent(shownKey))
    }

    @Test
    fun dismissEventWithoutAKeyStaysABareSignal() {
        assertEquals(mapOf("type" to "dismissed"), swapLiveDismissEvent(null))
        assertEquals(mapOf("type" to "dismissed"), swapLiveDismissEvent(""))
    }

    @Test
    fun aLocalShowCanStartTheFirstCard() {
        assertTrue(localShow(shownKey, 1000, "settling", null, null, stored(1000, "swapped", null)))
    }

    @Test
    fun aNewSwapReplacesAFinishedCard() {
        assertTrue(localShow("other|2", 1000, "settling", null, shownKey, stored(5000, "swapped", null)))
    }

    @Test
    fun aNewerSettlingShowDoesNotReopenTheSameSwap() {
        assertFalse(localShow(shownKey, 4000, "settling", null, shownKey, stored(3000, "swapped", null)))
    }

    @Test
    fun anUnfinishedCardStillRefreshes() {
        assertTrue(localShow(shownKey, 4000, "settling", null, shownKey, stored(1000, "settling", null)))
    }

    @Test
    fun theSameLocalRevisionStillRefreshes() {
        assertTrue(localShow(shownKey, 2000, "settling", null, shownKey, stored(2000, "settling", null)))
    }

    @Test
    fun anIncompleteDepositStillAcceptsALocalSettlingShow() {
        assertTrue(localShow(shownKey, 2000, "settling", null, shownKey, stored(1000, "failed", "incomplete")))
    }

    @Test
    fun aPushWithoutARevisionIsDropped() {
        val data = settling(2000).toMutableMap()
        data.remove("updatedAt")
        assertNull(update(data, stored(1000, "settling", null)))
    }

    @Test
    fun dismissedCardIsLeftAlone() {
        val stored = stored(1000, "settling", null)
        assertNull(swapLivePushFields(swapped(3000), shownKey, shownKey, stored))
    }

    @Test
    fun nestedOlderContentStateIsDropped() {
        val wrapped = mapOf(
            "type" to "swap_live_activity",
            "content_state" to settling(1000),
        )
        assertNull(swapLivePushFields(wrapped, shownKey, null, stored(2000, "swapped", null)))
    }

    @Test
    fun aNewerRefundAfterSwappedIsAllowed() {
        val refund = mapOf(
            "type" to "swap_live_activity",
            "phase" to "failed",
            "failure" to "refunded",
            "key" to shownKey,
            "updatedAt" to 3000L,
            "holdsProcess" to false,
        )
        val card = swapLivePushFields(refund, shownKey, null, stored(2000, "swapped", null))
        assertEquals("failed", card!!["phase"])
        assertEquals("refunded", card["failure"])
    }

    private fun update(data: Map<String, Any?>, stored: SwapLiveCardRevision): Map<String, Any?>? {
        return swapLivePushFields(data, shownKey, null, stored)
    }

    private fun localShow(
        incomingKey: String,
        updatedAt: Long,
        phase: String,
        failure: String?,
        storedKey: String?,
        stored: SwapLiveCardRevision,
        dismissedKey: String? = null,
    ): Boolean {
        return swapLiveLocalWriteAllowed(incomingKey, updatedAt, phase, failure, storedKey, stored, dismissedKey)
    }

    private fun stored(updatedAt: Long, phase: String, failure: String?): SwapLiveCardRevision {
        return SwapLiveCardRevision(updatedAt, phase, failure)
    }

    private fun settling(updatedAt: Long): Map<String, Any?> = push("settling", updatedAt, holds = true)

    private fun swapped(updatedAt: Long): Map<String, Any?> = push("swapped", updatedAt, holds = false)

    private fun push(phase: String, updatedAt: Long, holds: Boolean): Map<String, Any?> {
        return mapOf(
            "type" to "swap_live_activity",
            "phase" to phase,
            "key" to shownKey,
            "updatedAt" to updatedAt,
            "holdsProcess" to holds,
        )
    }
}
