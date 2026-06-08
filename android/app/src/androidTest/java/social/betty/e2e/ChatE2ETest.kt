package social.betty.e2e

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Group chat (MemeBoard): the board renders the group's seeded messages (components.md §5). */
@RunWith(AndroidJUnit4::class)
class ChatE2ETest : BettyUiTestCase() {

    @Test
    fun chatBoardRendersSeededMessages() {
        launchApp()
        waitForTag("home-group-card")
        // First running group = "Sunday Legends", which has seeded chat messages.
        composeRule.onAllNodesWithTag("home-group-card").onFirst().performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)

        // The MemeBoard sits below the standings in the Group tab — scroll the lazy list to it.
        composeRule.onAllNodes(hasScrollAction()).onFirst()
            .performScrollToNode(hasTestTag("chat-message"))
        composeRule.onAllNodesWithTag("chat-message").onFirst().assertIsDisplayed()
    }
}
