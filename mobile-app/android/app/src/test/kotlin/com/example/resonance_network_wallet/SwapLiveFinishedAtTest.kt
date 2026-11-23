package com.example.resonance_network_wallet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/// The app redraws a finished card with a fresh updatedAt every refresh. The
/// card still leaves on the deadline set by its first finished write.
class SwapLiveFinishedAtTest {
    private val settledAt = minutes(6 * 60)

    @Test
    fun theFirstFinishedWriteFixesTheFinishTime() {
        assertEquals(settledAt, finishedAt("swap-a", "swapped", null, updatedAt = settledAt, stored = null))
    }

    @Test
    fun aRegeneratedFinishedPayloadKeepsTheFirstDeadline() {
        // Settled at 06:00. The 06:14 refresh rebuilds the payload with updatedAt 06:14.
        val redraw = settledAt + minutes(14)
        val kept = finishedAt("swap-a", "swapped", null, updatedAt = redraw, stored = "swap-a" to settledAt)

        assertEquals(settledAt, kept)
        assertEquals(minutes(1), swapLiveTimeoutMs("swapped", null, finishedAtMs = kept, nowMs = redraw))
    }

    @Test
    fun aRegeneratedRefundKeepsTheFirstDeadline() {
        val redraw = settledAt + minutes(20)
        val kept = finishedAt("swap-a", "failed", "refunded", updatedAt = redraw, stored = "swap-a" to settledAt)

        assertEquals(settledAt, kept)
        assertEquals(minutes(10), swapLiveTimeoutMs("failed", "refunded", finishedAtMs = kept, nowMs = redraw))
    }

    @Test
    fun aSwapThatWasStillOpenStartsItsClockWhenItFinishes() {
        val finish = settledAt + minutes(3)
        assertEquals(finish, finishedAt("swap-a", "swapped", null, updatedAt = finish, stored = "swap-a" to null))
    }

    @Test
    fun aDifferentSwapStartsItsOwnClock() {
        val later = settledAt + minutes(40)
        assertEquals(later, finishedAt("swap-b", "swapped", null, updatedAt = later, stored = "swap-a" to settledAt))
    }

    @Test
    fun aSwapStillOpenHasNoFinishTime() {
        for (phase in listOf("submitted", "confirming", "settling")) {
            assertNull(phase, finishedAt("swap-a", phase, null, updatedAt = settledAt, stored = "swap-a" to settledAt))
        }
        assertNull(finishedAt("swap-a", "failed", "incomplete", updatedAt = settledAt, stored = null))
    }

    private fun finishedAt(
        key: String,
        phase: String,
        failure: String?,
        updatedAt: Long?,
        stored: Pair<String, Long?>?,
    ) = swapLiveFinishedAtMs(key, phase, failure, updatedAt, stored?.first, stored?.second)

    private fun minutes(count: Long) = count * 60_000L
}
