package social.betty.e2e

import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.mock.DefaultScenario
import social.betty.support.BettyUiTestCase

/** Signed-out launch + the email sign-in flow (screens.md §3.1). */
@RunWith(AndroidJUnit4::class)
class AuthE2ETest : BettyUiTestCase() {

    override val seedsAuthentication: Boolean get() = false

    @Test
    fun signedOutLaunchShowsAuthScreen() {
        launchApp()
        assertTag("auth-screen")
    }

    @Test
    fun emailSignInLandsOnHome() {
        launchApp()
        assertTag("auth-screen")

        // Reveal the collapsed email form, fill credentials, submit.
        clickTag("auth-email-toggle")
        composeRule.onNodeWithTag("auth-email-field").performTextInput(DefaultScenario.CURRENT_USER_EMAIL)
        composeRule.onNodeWithTag("auth-password-field").performTextInput(DefaultScenario.CURRENT_USER_PASSWORD)
        composeRule.onNodeWithTag("auth-submit").performClick()

        // Seeded user already has a profile → straight to the home tab.
        assertTag("tab-home", timeoutMillis = 15_000)
    }
}
