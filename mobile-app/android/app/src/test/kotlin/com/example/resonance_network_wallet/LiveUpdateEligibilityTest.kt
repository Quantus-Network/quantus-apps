package com.example.resonance_network_wallet

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveUpdateEligibilityTest {
    @Test
    fun ongoingProgressOnAuthorizedAndroid16MinorIsEligible() {
        assertTrue(
            liveUpdateEligible(
                sdkInt = 36,
                sdkFull = LIVE_UPDATE_MIN_SDK_FULL,
                authorized = true,
                ongoing = true,
                showProgress = true,
                hasTitle = true,
            ),
        )
    }

    @Test
    fun laterPlatformsStayEligible() {
        assertTrue(
            liveUpdateEligible(
                sdkInt = 37,
                sdkFull = 3_700_000,
                authorized = true,
                ongoing = true,
                showProgress = true,
                hasTitle = true,
            ),
        )
    }

    @Test
    fun android16InitialReleaseStaysOnTheCustomCard() {
        assertFalse(eligible(sdkFull = LIVE_UPDATE_MIN_SDK_FULL - 1))
    }

    @Test
    fun olderPlatformsStayOnTheCustomCard() {
        assertFalse(eligible(sdkInt = 35, sdkFull = 3_500_000))
    }

    @Test
    fun unauthorizedDevicesStayOnTheCustomCard() {
        assertFalse(eligible(authorized = false))
    }

    @Test
    fun finishedOrStaleCardsStayOnTheCustomCard() {
        assertFalse(eligible(ongoing = false))
        assertFalse(eligible(showProgress = false))
    }

    @Test
    fun aCardWithoutATitleCannotBePromoted() {
        assertFalse(eligible(hasTitle = false))
    }

    private fun eligible(
        sdkInt: Int = 36,
        sdkFull: Int = LIVE_UPDATE_MIN_SDK_FULL,
        authorized: Boolean = true,
        ongoing: Boolean = true,
        showProgress: Boolean = true,
        hasTitle: Boolean = true,
    ): Boolean = liveUpdateEligible(sdkInt, sdkFull, authorized, ongoing, showProgress, hasTitle)
}
