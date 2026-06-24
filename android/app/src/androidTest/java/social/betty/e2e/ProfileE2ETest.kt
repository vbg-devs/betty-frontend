package social.betty.e2e

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Profile tab: shows the seeded user, sign-out returns to auth (screens.md §3.9). */
@RunWith(AndroidJUnit4::class)
class ProfileE2ETest : BettyUiTestCase() {

    @Test
    fun profileShowsSeededUser() {
        launchApp()
        clickTag("tab-profile")
        assertTag("profile-screen")
        assertTag("profile-name")
    }

    @Test
    fun signOutReturnsToAuth() {
        launchApp()
        clickTag("tab-profile")
        assertTag("profile-screen")
        // Sign out lives at the bottom of the scrollable profile column.
        composeRule.onNodeWithTag("profile-signout").performScrollTo().performClick()
        assertTag("auth-screen", timeoutMillis = 15_000)
    }
}
