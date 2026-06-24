package social.betty.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import social.betty.designsystem.BettyTheme

class MainActivity : ComponentActivity() {

    private val container: AppContainer get() = (application as BettyApplication).container
    // Owned here (not in composition) so the Google OAuth redirect handler can resume sign-in.
    private val appState: AppState by lazy { AppState(container) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (LaunchOverrides.isUiTestRun()) {
            container.resetForUiTest()
        }

        setContent {
            LaunchedEffect(Unit) { appState.start(lifecycleScope) }
            BettyTheme(mode = container.themeStore.mode) {
                RootScreen(appState = appState, container = container)
            }
        }

        handleAuthRedirect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthRedirect(intent)
    }

    /** Completes a Google sign-in when the Custom Tab redirects back via the reversed-client scheme. */
    private fun handleAuthRedirect(intent: Intent?) {
        val uri = intent?.data ?: return
        if (GoogleSignInCoordinator.matches(uri)) {
            lifecycleScope.launch { GoogleSignInCoordinator.complete(uri, container, appState) }
        }
    }
}
