package com.example.resonance_network_wallet

import org.junit.Assert.assertEquals
import org.junit.Test

class SwapLiveTimeLeftTest {
    private val minute = "min"
    private val hour = "hr"
    private val left = "left"

    @Test
    fun anExactFiveMinutesReadsAsFiveMinLeft() {
        assertEquals("~5 min left", left(now = 0, endsAt = minutes(5)))
    }

    @Test
    fun aPartialMinuteRoundsUpUntilTheNextWholeMinute() {
        assertEquals("~5 min left", left(now = 0, endsAt = minutes(4) + 1_000))
        assertEquals("~4 min left", left(now = 0, endsAt = minutes(4)))
    }

    @Test
    fun noTimeLeftIsZeroMinutes() {
        assertEquals("~0 min left", left(now = minutes(5), endsAt = minutes(5)))
        assertEquals("~0 min left", left(now = minutes(6), endsAt = minutes(5)))
    }

    @Test
    fun anHourDropsTheMinuteUnitAndARemainderKeepsBoth() {
        assertEquals("~1 hr left", left(now = 0, endsAt = minutes(60)))
        assertEquals("~1 hr 30 min left", left(now = 0, endsAt = minutes(90)))
    }

    @Test
    fun aBlankUnitUsesTheWordFromCardsThatPredateTheLabel() {
        assertEquals("~5 min left", swapLiveTimeLeft(0, minutes(5), minute = "", hour = "", left = ""))
    }

    private fun left(now: Long, endsAt: Long) = swapLiveTimeLeft(now, endsAt, minute, hour, left)

    private fun minutes(count: Int) = count * 60_000L
}
