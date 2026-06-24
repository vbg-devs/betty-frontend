package social.betty.e2e

import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Home dashboard: hero, group cards, the new-group sheet, and card → group detail (screens.md §3.2). */
@RunWith(AndroidJUnit4::class)
class HomeE2ETest : BettyUiTestCase() {

    @Test
    fun heroAndGroupCardsRender() {
        launchApp()
        assertTag("home-screen")
        assertTag("home-hero")
        val cards = composeRule.onAllNodesWithTag("home-group-card").fetchSemanticsNodes()
        assertTrue("seeded user has running groups", cards.isNotEmpty())
    }

    @Test
    fun newGroupButtonOpensCreateSheet() {
        launchApp()
        clickTag("home-new-group")
        assertTag("create-group-sheet")
    }

    @Test
    fun tappingGroupCardOpensGroupDetail() {
        launchApp()
        waitForTag("home-group-card")
        composeRule.onAllNodesWithTag("home-group-card").onFirst().performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)
    }
}
