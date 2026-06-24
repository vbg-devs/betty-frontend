package social.betty.e2e

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.support.BettyUiTestCase

/** Browse public groups + search (screens.md §3.4). */
@RunWith(AndroidJUnit4::class)
class BrowseJoinE2ETest : BettyUiTestCase() {

    @Test
    fun browseTabListsPublicGroups() {
        launchApp()
        clickTag("tab-browse")
        assertTag("browse-screen")
        // The seeded "Open Arena" public group is returned by GET /groups/public.
        waitForTag("browse-card", timeoutMillis = 15_000)
        val cards = composeRule.onAllNodesWithTag("browse-card").fetchSemanticsNodes()
        assertTrue("public groups returned", cards.isNotEmpty())
    }

    @Test
    fun searchFieldIsPresent() {
        launchApp()
        clickTag("tab-browse")
        assertTag("browse-screen")
        waitForTag("browse-search")
        composeRule.onNodeWithTag("browse-search").assertIsDisplayed()
    }
}
