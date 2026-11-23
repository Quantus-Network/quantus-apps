package com.example.resonance_network_wallet

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// A finished card has nothing left to check, so it never turns stale before it times out.
class SwapLiveStaleTest {
    @Test
    fun aFinishedSwapDoesNotScheduleTheStaleAlarm() {
        assertFalse(swapLiveSchedulesStale("swapped", null))
        assertFalse(swapLiveSchedulesStale("failed", "failed"))
        assertFalse(swapLiveSchedulesStale("failed", "refunded"))
    }

    @Test
    fun aSwapStillMovingSchedulesTheStaleAlarm() {
        for (phase in listOf("submitted", "confirming", "settling")) {
            assertTrue(phase, swapLiveSchedulesStale(phase, null))
        }
    }

    @Test
    fun anIncompleteDepositSchedulesTheStaleAlarm() {
        assertTrue(swapLiveSchedulesStale("failed", "incomplete"))
    }
}
