package social.betty.app

import android.Manifest
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import social.betty.core.push.PushPermission
import social.betty.designsystem.BettyTheme
import social.betty.navigation.DeepLink

class MainActivity : ComponentActivity() {

    private val container: AppContainer get() = (application as BettyApplication).container
    // Owned here (not in composition) so the Google OAuth redirect handler can resume sign-in.
    private val appState: AppState by lazy { AppState(container) }

    companion object {
        /** Intent extra carrying a notification's deep-link url (our foreground PendingIntent). */
        const val EXTRA_PUSH_URL = "betty:push-url"
    }

    private var permissionContinuation: CompletableDeferred<Boolean>? = null
    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            permissionContinuation?.complete(granted)
            permissionContinuation = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (LaunchOverrides.isUiTestRun()) {
            container.resetForUiTest()
        }

        // Only an Activity can show the OS permission dialog. On < 33 isGranted() is already true.
        container.notificationPermissionRequester = {
            if (PushPermission.isGranted(this)) {
                true
            } else {
                val deferred = CompletableDeferred<Boolean>()
                permissionContinuation = deferred
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                deferred.await()
            }
        }

        setContent {
            LaunchedEffect(Unit) { appState.start(lifecycleScope) }
            BettyTheme(mode = container.themeStore.mode) {
                RootScreen(appState = appState, container = container)
            }
        }

        handleAuthRedirect(intent)
        // Only on a genuine cold start — NOT a config-change recreation, which re-delivers the
        // same retained launch intent and would re-open the bet sheet (handlePushDeepLink also
        // consumes the extra as a second guard).
        if (savedInstanceState == null) handlePushDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthRedirect(intent)
        handlePushDeepLink(intent) // warm notification tap → enqueueDeepLink → RootScreen re-applies
    }

    /** Completes a Google sign-in when the Custom Tab redirects back via the reversed-client scheme. */
    private fun handleAuthRedirect(intent: Intent?) {
        val uri = intent?.data ?: return
        if (GoogleSignInCoordinator.matches(uri)) {
            lifecycleScope.launch { GoogleSignInCoordinator.complete(uri, container, appState) }
        }
    }

    /** Route a notification tap. Reads our custom extra (foreground PendingIntent) OR the
     *  system-merged "url" extra FCM places in the launcher intent for a BACKGROUND tray tap.
     *  Strict — only parseable deep links are honored (mirrors iOS safeReturnUrl). */
    private fun handlePushDeepLink(intent: Intent?) {
        val i = intent ?: return
        val raw = i.getStringExtra(EXTRA_PUSH_URL) ?: i.getStringExtra("url") ?: return
        // Consume the extra so a retained launch intent can't re-deliver this link on a later
        // config-change recreation (rotation/theme/font-size) — which would re-open the sheet.
        i.removeExtra(EXTRA_PUSH_URL)
        i.removeExtra("url")
        setIntent(i)
        if (DeepLink.parse(raw) != null) appState.enqueueDeepLink(raw)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Drop the Activity-capturing permission requester so a destroyed Activity isn't leaked
        // by the process-scoped container; a recreated MainActivity re-installs its own in onCreate.
        container.notificationPermissionRequester = { PushPermission.isGranted(applicationContext) }
    }
}
