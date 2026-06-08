package social.betty.e2e

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/**
 * Harness smoke test: launches the app against the in-process mock backend with seeded auth
 * and asserts the bottom tab bar appears — proving the override plumbing, seeded-auth fast
 * path, mock HTTP/identity/securetoken servers, and Compose rule all work together.
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest : BettyUiTestCase() {

    @Test
    fun launchesIntoHomeWithSeededAuth() {
        launchApp()
        assertTag("tab-home")
        assertTag("home-screen")
    }

    @Test
    fun bottomBarSwitchesBetweenAllTabs() {
        launchApp()
        clickTag("tab-browse"); assertTag("browse-screen")
        clickTag("tab-leaderboard"); assertTag("leaderboard-screen")
        clickTag("tab-activity"); assertTag("activity-screen")
        clickTag("tab-profile"); assertTag("profile-screen")
        clickTag("tab-home"); assertTag("home-screen")
    }
}
