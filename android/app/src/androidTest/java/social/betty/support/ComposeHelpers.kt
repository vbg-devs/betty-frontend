package social.betty.support

import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick

/**
 * Thin Compose-test conveniences over [ComposeTestRule.onNodeWithTag], used by [BettyUiTestCase] and
 * available directly to suites that want them on their own rule.
 */

/** Spins the idling-resource clock until a node with [testTag] exists, then returns the interaction. */
fun ComposeTestRule.waitForTag(testTag: String, timeoutMillis: Long = 10_000): SemanticsNodeInteraction {
    waitUntil(timeoutMillis) {
        onAllNodesWithTagCount(testTag) > 0
    }
    return onNodeWithTag(testTag)
}

/** Waits for, then asserts the node with [testTag] is displayed. */
fun ComposeTestRule.assertTag(testTag: String, timeoutMillis: Long = 10_000): SemanticsNodeInteraction =
    waitForTag(testTag, timeoutMillis).assertIsDisplayed()

/** Waits for, then clicks the node with [testTag]. */
fun ComposeTestRule.clickTag(testTag: String, timeoutMillis: Long = 10_000): SemanticsNodeInteraction =
    waitForTag(testTag, timeoutMillis).also { it.performClick() }

private fun ComposeTestRule.onAllNodesWithTagCount(testTag: String): Int =
    onAllNodesWithTag(testTag)
        .fetchSemanticsNodes(atLeastOneRootRequired = false)
        .size
