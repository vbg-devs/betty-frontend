package social.betty.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.ToastData
import social.betty.designsystem.components.ToastHost
import social.betty.designsystem.components.ToastKind
import social.betty.features.auth.AuthScreen
import social.betty.features.auth.CompleteProfileScreen
import social.betty.navigation.AppNavigator
import social.betty.navigation.DeepLink
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalAppState
import social.betty.navigation.LocalNavigator
import social.betty.navigation.MainScaffold
import social.betty.navigation.apply as applyDeepLink
import social.betty.core.store.NoticeKind

/**
 * Root switch on [AppPhase] (screens.md §2). Provides the navigation composition locals and
 * hosts the global toast overlay. A deep link captured while signed out is replayed once the
 * phase becomes Ready.
 */
@Composable
fun RootScreen(appState: AppState, container: AppContainer) {
    val phase by appState.phase.collectAsStateWithLifecycle()
    val navigator = remember { AppNavigator() }
    val colors = BettyTheme.colors

    CompositionLocalProvider(
        LocalAppContainer provides container,
        LocalAppState provides appState,
        LocalNavigator provides navigator,
    ) {
        Box(modifier = Modifier.fillMaxSize().background(colors.background)) {
            when (phase) {
                AppPhase.Launching -> SplashContent()
                AppPhase.SignedOut -> AuthScreen()
                AppPhase.NeedsProfile -> CompleteProfileScreen()
                AppPhase.Ready -> {
                    LaunchedEffect(Unit) {
                        appState.pendingDeepLink?.let { raw ->
                            DeepLink.parse(raw)?.let { navigator.applyDeepLink(it) }
                            appState.pendingDeepLink = null
                        }
                    }
                    MainScaffold()
                }
                is AppPhase.BootFailed -> BootFailedContent((phase as AppPhase.BootFailed).message)
            }

            ToastOverlay(container)
        }
    }
}

@Composable
private fun ToastOverlay(container: AppContainer) {
    val notices by container.notify.notices.collectAsStateWithLifecycle()
    val toasts = notices.map { notice ->
        ToastData(
            message = notice.message,
            kind = when (notice.kind) {
                NoticeKind.SUCCESS -> ToastKind.SUCCESS
                NoticeKind.INFO -> ToastKind.INFO
                NoticeKind.ERROR, NoticeKind.CRITICAL -> ToastKind.ERROR
            },
        )
    }
    ToastHost(toasts = toasts, onDismiss = { toast ->
        notices.getOrNull(toasts.indexOf(toast))?.let { container.notify.dismiss(it.id) }
    })
}

@Composable
private fun SplashContent() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.l),
            modifier = Modifier.testTag("splash"),
        ) {
            Text("BETTY", style = type.displayL.copy(color = colors.textPrimary))
            CircularProgressIndicator(color = Palette.orange, modifier = Modifier.size(28.dp))
        }
    }
}

@Composable
private fun BootFailedContent(message: String) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val appState = LocalAppState.current
    val scope = rememberCoroutineScope()
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.l),
            modifier = Modifier.testTag("boot-failed").padding(Space.xxl),
        ) {
            Text(
                text = message,
                style = type.headline.copy(color = colors.textPrimary),
                textAlign = TextAlign.Center,
            )
            BettyButton(
                text = "Try again",
                onClick = { appState.retryBoot(scope) },
                variant = BettyButtonVariant.PRIMARY,
            )
        }
    }
}
