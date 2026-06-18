package social.betty.app

import android.content.Context
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.OkHttpClient
import social.betty.core.auth.FirebaseAuthClient
import social.betty.core.auth.SessionManager
import social.betty.core.auth.TokenStore
import social.betty.core.net.ApiClient
import social.betty.core.net.BettyApi
import social.betty.core.push.FirebaseAvailability
import social.betty.core.push.PushPermission
import social.betty.core.push.PushRegistrationService
import social.betty.core.push.SentTokenStore
import social.betty.core.store.ActivityFeedStore
import social.betty.core.store.BetStore
import social.betty.core.store.CountriesProvider
import social.betty.core.store.GameStore
import social.betty.core.store.GroupStore
import social.betty.core.store.NotifyCenter
import social.betty.core.store.Preferences
import social.betty.core.store.TeamStore
import social.betty.core.store.TournamentStore
import social.betty.core.store.UserStore
import social.betty.core.ws.ActivitySocket
import social.betty.designsystem.ThemeStore
import java.util.concurrent.TimeUnit

/**
 * Process-wide service locator (the iOS `AppEnvironment` analogue), created once in
 * [BettyApplication]. Wires the networking/auth/store singletons that screens and [AppState]
 * resolve without a DI framework.
 */
class AppContainer(context: Context) {
    val appContext: Context = context.applicationContext
    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    val themeStore = ThemeStore(appContext)
    val preferences = Preferences(appContext)
    val notify = NotifyCenter()

    val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val wsClient: OkHttpClient = httpClient.newBuilder()
        .readTimeout(0, TimeUnit.MILLISECONDS) // long-lived socket
        .build()

    val authClient = FirebaseAuthClient(httpClient)
    val tokenStore = TokenStore(appContext)
    val sessionManager = SessionManager(authClient, tokenStore)

    val apiClient = ApiClient(
        http = httpClient,
        tokenProvider = sessionManager,
        baseUrlProvider = { AppConfig.apiBaseUrl },
    )
    val api = BettyApi(apiClient)

    val socket = ActivitySocket(wsClient, { AppConfig.webSocketUrl }, appScope)

    val userStore = UserStore()
    val groupStore = GroupStore(api)
    val tournamentStore = TournamentStore(api)
    val betStore = BetStore(api)
    val gameStore = GameStore(api)
    val teamStore = TeamStore(api)
    val activityFeed = ActivityFeedStore()
    val countries = CountriesProvider(api)

    // ── Push (FCM) — REST-only auth unaffected; only Messaging is linked (CLAUDE.md carve-out).
    private val sentPushTokenStore = object : SentTokenStore {
        override fun get(): String? = preferences.sentPushToken()
        override fun set(token: String?) = preferences.setSentPushToken(token)
    }

    /** Set by MainActivity (only an Activity can prompt). Default = the real grant state and
     *  never prompts, so registration off the main loop reports authorization truthfully. */
    @Volatile
    var notificationPermissionRequester: suspend () -> Boolean = { PushPermission.isGranted(appContext) }

    val push = PushRegistrationService(
        appScope = appScope,
        sentTokenStore = sentPushTokenStore,
        sendToken = { token -> api.addPushToken(token) },
        requestAuthorization = { notificationPermissionRequester() },
        fetchToken = { if (FirebaseAvailability.isConfigured(appContext)) fetchFcmToken() else null },
        isFirebaseConfigured = { FirebaseAvailability.isConfigured(appContext) },
    )

    /** FCM registration token as a suspend value. suspendCancellableCoroutine avoids pulling in
     *  kotlinx-coroutines-play-services, keeping the Messaging carve-out minimal. */
    private suspend fun fetchFcmToken(): String? = runCatching {
        suspendCancellableCoroutine { cont ->
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                cont.resumeWith(Result.success(if (task.isSuccessful) task.result else null))
            }
        }
    }.getOrNull()

    /**
     * Wipes persisted + in-memory client state for a deterministic UI-test launch. The
     * container is a process singleton reused across instrumentation tests, so the live
     * session and user store must be cleared too (not just persisted prefs).
     */
    fun resetForUiTest() {
        appContext.getSharedPreferences("betty-prefs", Context.MODE_PRIVATE).edit().clear().apply()
        sessionManager.resetForTest()
        userStore.set(null)
        socket.disconnect()
    }
}
