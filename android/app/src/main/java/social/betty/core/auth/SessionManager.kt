package social.betty.core.auth

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import social.betty.core.net.TokenProvider
import java.time.Instant

/** Provider profile hints captured at interactive sign-in to prefill complete-profile. */
data class ProviderProfile(
    val email: String?,
    val displayName: String?,
    val photoUrl: String?,
)

/**
 * Owns the live [AuthSession] and serves a valid ID token to [social.betty.core.net.ApiClient]
 * (it implements [TokenProvider]). Refreshes proactively when < 5 min remain, serializing
 * concurrent refreshes behind one mutex (data-layer.md §3.2). A refresh failure that forces
 * sign-out wipes the persisted token and returns null (callers route to the landing screen).
 */
class SessionManager(
    private val authClient: FirebaseAuthClient,
    private val tokenStore: TokenStore,
) : TokenProvider {

    @Volatile
    private var current: AuthSession? = null

    @Volatile
    var providerProfile: ProviderProfile? = null
        private set

    private val mutex = Mutex()

    val uid: String? get() = current?.uid
    val isAuthenticated: Boolean get() = current != null

    /** Adopts an interactive sign-in result, persisting the refresh token. */
    suspend fun signIn(session: AuthSession) = mutex.withLock {
        current = session
        providerProfile = ProviderProfile(session.email, session.displayName, session.photoUrl)
        tokenStore.save(session.refreshToken, session.uid)
    }

    /** Seeds a persisted refresh token (used by the seeded-auth e2e fast path). */
    fun seed(refreshToken: String, uid: String) {
        tokenStore.save(refreshToken, uid)
    }

    /** Restores a session from the persisted refresh token at boot, or null if none/invalid. */
    suspend fun restore(): AuthSession? = mutex.withLock { restoreLocked() }

    override suspend fun validToken(): String? = mutex.withLock {
        var session = current ?: restoreLocked() ?: return null
        if (Instant.now().isAfter(session.expiresAt.minusSeconds(300))) {
            session = refreshLocked(session.refreshToken) ?: return null
        }
        session.idToken
    }

    suspend fun signOut() = mutex.withLock {
        current = null
        providerProfile = null
        tokenStore.clear()
    }

    /**
     * Synchronous in-memory + persisted reset for a deterministic UI-test launch. The
     * [AppContainer] is a process singleton reused across instrumentation tests, so the live
     * session must be wiped (not just the token store) or a signed-out test would still see a
     * stale session from an earlier signed-in test.
     */
    fun resetForTest() {
        current = null
        providerProfile = null
        tokenStore.clear()
    }

    // --- mutex-held helpers ---------------------------------------------------

    private suspend fun restoreLocked(): AuthSession? {
        val (refreshToken, _) = tokenStore.load() ?: return null
        return refreshLocked(refreshToken)
    }

    private suspend fun refreshLocked(refreshToken: String): AuthSession? = try {
        val refreshed = authClient.refresh(refreshToken)
        current = refreshed
        tokenStore.save(refreshed.refreshToken, refreshed.uid)
        refreshed
    } catch (e: AuthException) {
        if (e.forcesSignOut) {
            current = null
            tokenStore.clear()
        }
        null
    } catch (e: Exception) {
        // Transient (network) failure: keep the (possibly stale) session for a later retry.
        null
    }
}
