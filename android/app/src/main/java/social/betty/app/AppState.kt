package social.betty.app

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import social.betty.core.model.UserProfile
import social.betty.core.net.ApiError

/**
 * Owns the root [AppPhase] and the boot sequence (screens.md §1, data-layer.md §3.3):
 * restore/seed the refresh token → mint an ID token → `GET /user/me` (404 → [NeedsProfile])
 * → parallel bootstrap of teams/tournaments/groups → [Ready]; auth-invalid → [SignedOut];
 * network failure → [BootFailed]. A deep link captured while signed out is replayed on Ready.
 */
class AppState(private val container: AppContainer) {
    private val _phase = MutableStateFlow<AppPhase>(AppPhase.Launching)
    val phase: StateFlow<AppPhase> = _phase.asStateFlow()

    /** A deep link captured before the app was Ready, replayed once boot completes. */
    @Volatile
    var pendingDeepLink: String? = null

    fun start(scope: kotlinx.coroutines.CoroutineScope) {
        scope.launch { boot() }
    }

    private suspend fun boot() {
        LaunchOverrides.seededRefreshTokenOrNull()?.let { refresh ->
            LaunchOverrides.seededUidOrNull()?.let { uid -> container.sessionManager.seed(refresh, uid) }
        }
        val token = container.sessionManager.validToken()
        if (token == null) {
            _phase.value = AppPhase.SignedOut
            return
        }
        resolveProfileAndReady()
    }

    /** Called by the Auth feature after a successful interactive sign-in (session already set). */
    suspend fun onInteractiveSignIn() = resolveProfileAndReady()

    /** Called by CompleteProfile after `POST /user`. */
    suspend fun onProfileCompleted(profile: UserProfile) {
        container.userStore.set(profile)
        bootstrapAndReady()
    }

    fun signOut(scope: kotlinx.coroutines.CoroutineScope) {
        scope.launch {
            container.sessionManager.signOut()
            container.socket.disconnect()
            container.userStore.set(null)
            _phase.value = AppPhase.SignedOut
        }
    }

    fun retryBoot(scope: kotlinx.coroutines.CoroutineScope) {
        _phase.value = AppPhase.Launching
        scope.launch { boot() }
    }

    private suspend fun resolveProfileAndReady() {
        try {
            container.userStore.set(container.api.getUserMe())
            bootstrapAndReady()
        } catch (e: ApiError.Status) {
            when (e.code) {
                404 -> _phase.value = AppPhase.NeedsProfile
                401, 403 -> {
                    container.sessionManager.signOut()
                    _phase.value = AppPhase.SignedOut
                }
                else -> _phase.value = AppPhase.BootFailed("Could not load your data. Please try again.")
            }
        } catch (e: Exception) {
            _phase.value = AppPhase.BootFailed("Could not load your data. Please try again.")
        }
    }

    private suspend fun bootstrapAndReady() {
        coroutineScope {
            val results = awaitAll(
                async { runCatching { container.teamStore.load() } },
                async { runCatching { container.tournamentStore.load() } },
                async { runCatching { container.groupStore.load() } },
            )
            if (results.any { it.isFailure }) {
                container.notify.critical("Could not load your data. Please refresh.")
            }
        }
        container.appScope.launch { runCatching { container.countries.load() } }
        container.socket.connect()
        _phase.value = AppPhase.Ready
    }
}
