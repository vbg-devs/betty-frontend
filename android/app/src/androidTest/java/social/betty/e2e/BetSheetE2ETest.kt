package social.betty.e2e

import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Opening the bet sheet from a game card (screens.md §3.3, components.md §2.4). */
@RunWith(AndroidJUnit4::class)
class BetSheetE2ETest : BettyUiTestCase() {

    @Test
    fun tappingGameCardOpensBetSheet() {
        launchApp()
        waitForTag("home-group-card")
        // The first running group uses the running tournament, which has games.
        composeRule.onAllNodesWithTag("home-group-card").onFirst().performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)

        clickTag("group-tab-games")
        waitForTag("group-game-card", timeoutMillis = 15_000)
        composeRule.onAllNodesWithTag("group-game-card").onFirst().performClick()

        // The bet sheet opens for any game; the save control only shows pre-kickoff
        // (a finished/started game force-switches to the read-only "Placed bets" tab).
        assertTag("bet-sheet", timeoutMillis = 15_000)
    }
}
