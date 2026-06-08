package social.betty.e2e

import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Group detail: hero, tabs, leaderboard (screens.md §3.3). */
@RunWith(AndroidJUnit4::class)
class GroupDetailE2ETest : BettyUiTestCase() {

    private fun openFirstGroup() {
        launchApp()
        waitForTag("home-group-card")
        composeRule.onAllNodesWithTag("home-group-card").onFirst().performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)
    }

    @Test
    fun groupDetailShowsHero() {
        openFirstGroup()
        assertTag("group-hero")
    }

    @Test
    fun leaderboardTabShowsRankedMembers() {
        openFirstGroup()
        clickTag("group-tab-leaderboard")
        waitForTag("group-leaderboard-row", timeoutMillis = 15_000)
        val rows = composeRule.onAllNodesWithTag("group-leaderboard-row").fetchSemanticsNodes()
        assertTrue("ranked members render", rows.isNotEmpty())
    }
}
