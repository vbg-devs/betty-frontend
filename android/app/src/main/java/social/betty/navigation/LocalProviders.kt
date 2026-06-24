package social.betty.navigation

import androidx.compose.runtime.staticCompositionLocalOf
import social.betty.app.AppContainer
import social.betty.app.AppState

/**
 * Ambient access to app singletons inside the Compose tree. Feature screens read
 * `LocalAppContainer.current` for stores/api, `LocalNavigator.current` to navigate, and
 * `LocalAppState.current` for sign-out / onboarding transitions.
 */
val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
    error("LocalAppContainer not provided")
}

val LocalAppState = staticCompositionLocalOf<AppState> {
    error("LocalAppState not provided")
}

val LocalNavigator = staticCompositionLocalOf<AppNavigator> {
    error("LocalNavigator not provided")
}
