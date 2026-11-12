package com.example.resonance_network_wallet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SwapLiveTimeoutTest {
    @Test
    fun aSwappedCardTimesOutFifteenMinutesAfterItFinished() {
        assertEquals(minutes(15), swapLiveTimeoutMs("swapped", null, finishedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aFailedOrRefundedCardTimesOutThirtyMinutesAfterItFinished() {
        assertEquals(minutes(30), swapLiveTimeoutMs("failed", "failed", finishedAtMs = 0, nowMs = 0))
        assertEquals(minutes(30), swapLiveTimeoutMs("failed", "refunded", finishedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aRepostCountsFromTheFinishNotFromThePost() {
        assertEquals(minutes(13), swapLiveTimeoutMs("swapped", null, finishedAtMs = 0, nowMs = minutes(2)))
    }

    @Test
    fun aCardPastItsWindowTimesOutAtOnce() {
        assertEquals(1L, swapLiveTimeoutMs("swapped", null, finishedAtMs = 0, nowMs = minutes(15)))
        assertEquals(1L, swapLiveTimeoutMs("failed", "refunded", finishedAtMs = 0, nowMs = minutes(60)))
    }

    @Test
    fun anIncompleteDepositNeverTimesOut() {
        assertNull(swapLiveTimeoutMs("failed", "incomplete", finishedAtMs = 0, nowMs = 0))
    }

    @Test
    fun aSwapStillMovingNeverTimesOut() {
        for (phase in listOf("submitted", "confirming", "settling")) {
            assertNull(phase, swapLiveTimeoutMs(phase, null, finishedAtMs = 0, nowMs = 0))
        }
    }

    @Test
    fun aFinishedCardWithoutAFinishTimeHasNoTimeout() {
        assertNull(swapLiveTimeoutMs("swapped", null, finishedAtMs = null, nowMs = 0))
    }

    private fun minutes(count: Long) = count * 60_000L
}
