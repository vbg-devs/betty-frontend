package social.betty.core.push

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Persists the last token successfully POSTed (iOS `UserDefaults["betty:push-token-sent"]`). */
interface SentTokenStore {
    fun get(): String?
    fun set(token: String?)
}

/**
 * Port of iOS `PushRegistrationService`: obtains the FCM registration token and POSTs it to
 * `POST /user/me/add_push_token`, exactly once per distinct token, with retry-on-failure,
 * sign-out reset, and same-install account-switch re-send. All side effects are injected so the
 * JVM unit test can drive it without Android/Firebase.
 *
 * Phases mirror iOS: Idle → (prompt) → AwaitingToken → Registered; Denied is terminal; Unavailable
 * is the no-google-services.json state.
 */
class PushRegistrationService(
    private val appScope: CoroutineScope,
    private val sentTokenStore: SentTokenStore,
    private val sendToken: suspend (String) -> Unit,        // = api.addPushToken
    private val requestAuthorization: suspend () -> Boolean, // POST_NOTIFICATIONS grant state
    private val fetchToken: suspend () -> String?,           // guarded FirebaseMessaging token
    private val isFirebaseConfigured: () -> Boolean,         // false on the no-google-services.json build
) {
    sealed interface Phase {
        data object Idle : Phase
        data object Denied : Phase
        data object AwaitingToken : Phase
        data class Registered(val token: String) : Phase
        data object Unavailable : Phase // not configured (no json) or token fetch failed — retryable
    }

    private val _phase = MutableStateFlow<Phase>(Phase.Idle)
    val phase: StateFlow<Phase> = _phase.asStateFlow()

    /**
     * Post-Ready trigger. Prompts once per install; repeat calls retry an unsent token. Same-install
     * account switch: FCM won't refire `onNewToken` (token unchanged), so we explicitly fetch the
     * cached token and POST it for the new user.
     */
    suspend fun registerIfNeeded() {
        when (val current = _phase.value) {
            Phase.Denied, Phase.AwaitingToken -> return // terminal / in-flight
            is Phase.Registered -> sendIfUnsent(current.token) // retry path
            Phase.Idle, Phase.Unavailable -> {
                // No google-services.json → push can never work. Mark Unavailable WITHOUT a
                // pointless permission prompt; a later registerIfNeeded re-checks (retryable).
                if (!isFirebaseConfigured()) {
                    _phase.value = Phase.Unavailable
                    return
                }
                if (!requestAuthorization()) {
                    _phase.value = Phase.Denied
                    return
                }
                _phase.value = Phase.AwaitingToken
                val token = fetchToken()
                if (token != null) {
                    handleToken(token)
                } else {
                    // Transient token-fetch failure → Unavailable (retryable, like iOS .unavailable)
                    // rather than stranded in the in-flight AwaitingToken state.
                    _phase.value = Phase.Unavailable
                }
            }
        }
    }

    /** Called from [BettyMessagingService.onNewToken]. */
    fun onNewToken(token: String) {
        appScope.launch { handleToken(token) }
    }

    suspend fun handleToken(token: String?) {
        if (token.isNullOrEmpty()) return
        _phase.value = Phase.Registered(token)
        sendIfUnsent(token)
    }

    /** Sign-out clears the marker so the next account re-POSTs its token. */
    fun resetForSignOut() {
        sentTokenStore.set(null)
        _phase.value = Phase.Idle
    }

    private suspend fun sendIfUnsent(token: String) {
        if (sentTokenStore.get() == token) return
        // On failure the marker stays unset, so the next registerIfNeeded() (Registered phase) retries.
        runCatching { sendToken(token) }.onSuccess { sentTokenStore.set(token) }
    }
}
