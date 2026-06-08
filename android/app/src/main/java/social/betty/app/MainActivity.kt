package social.betty.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.ThemeMode

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val container = (application as BettyApplication).container
        if (LaunchOverrides.isUiTestRun()) {
            container.resetForUiTest()
        }

        setContent {
            val appState = remember { AppState(container) }
            val scope = rememberCoroutineScope()
            LaunchedEffect(Unit) { appState.start(scope) }

            BettyTheme(mode = container.themeStore.mode) {
                RootScreen(appState = appState, container = container)
            }
        }
    }
}
