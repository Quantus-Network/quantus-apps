package com.example.resonance_network_wallet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SwapLiveTimeoutTest {
    @Test
    fun aSwappedCardTimesOutFifteenMinutesAfterItFinished() {
        assertEquals(minutes(15), swapLiveTimeoutMs("swapped", null, updatedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aFailedOrRefundedCardTimesOutThirtyMinutesAfterItFinished() {
        assertEquals(minutes(30), swapLiveTimeoutMs("failed", "failed", updatedAtMs = 0, nowMs = 0))
        assertEquals(minutes(30), swapLiveTimeoutMs("failed", "refunded", updatedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aRepostCountsFromTheFinishNotFromThePost() {
        assertEquals(minutes(13), swapLiveTimeoutMs("swapped", null, updatedAtMs = 0, nowMs = minutes(2)))
    }

    @Test
    fun aCardPastItsWindowTimesOutAtOnce() {
        assertEquals(1L, swapLiveTimeoutMs("swapped", null, updatedAtMs = 0, nowMs = minutes(15)))
        assertEquals(1L, swapLiveTimeoutMs("failed", "refunded", updatedAtMs = 0, nowMs = minutes(60)))
    }

    @Test
    fun anIncompleteDepositNeverTimesOut() {
        assertNull(swapLiveTimeoutMs("failed", "incomplete", updatedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aSwapStillMovingNeverTimesOut() {
        for (phase in listOf("submitted", "confirming", "settling")) {
            assertNull(phase, swapLiveTimeoutMs(phase, null, updatedAtMs = 0, nowMs = 0))
        }
    }

    @Test
    fun aFinishedCardWithoutAnUpdateTimeHasNoTimeout() {
        assertNull(swapLiveTimeoutMs("swapped", null, updatedAtMs = null, nowMs = 0))
    }

    private fun minutes(count: Long) = count * 60_000L
}
