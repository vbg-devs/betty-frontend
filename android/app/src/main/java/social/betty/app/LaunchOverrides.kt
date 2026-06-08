package social.betty.app

import social.betty.BuildConfig

/**
 * DEBUG-only launch overrides so the BettyUITests instrumentation runner can point every
 * network edge (API, Identity Toolkit, securetoken, WebSocket) at its in-process loopback
 * mock backend. The Android analogue of the iOS launch-environment keys: because the
 * instrumentation test shares the app's process, the test sets these fields directly
 * before launching `MainActivity` (no env-var plumbing needed). In release builds every
 * read is gated by [BuildConfig.DEBUG], so production endpoints always win.
 *
 * Mirrors iOS `LaunchOverrides`:
 * - [apiBaseUrl]          → replaces `https://api.betty.social/api/v1`
 * - [identityBaseUrl]     → replaces `https://identitytoolkit.googleapis.com`
 * - [secureTokenBaseUrl]  → replaces `https://securetoken.googleapis.com`
 * - [webSocketUrl]        → replaces `wss://api.betty.social/ws`
 * - [isUiTest]            → wipe persisted session + prefs at launch, then seed below
 * - [seededRefreshToken] / [seededUid] → pre-authenticated fast path
 * - [disableAnimations]  → reduce animations for deterministic UI tests
 */
object LaunchOverrides {
    @Volatile var apiBaseUrl: String? = null
    @Volatile var identityBaseUrl: String? = null
    @Volatile var secureTokenBaseUrl: String? = null
    @Volatile var webSocketUrl: String? = null
    @Volatile var isUiTest: Boolean = false
    @Volatile var seededRefreshToken: String? = null
    @Volatile var seededUid: String? = null
    @Volatile var disableAnimations: Boolean = false

    private fun <T> gated(value: T?): T? = if (BuildConfig.DEBUG) value else null

    fun apiBaseUrlOrNull(): String? = gated(apiBaseUrl)
    fun identityBaseUrlOrNull(): String? = gated(identityBaseUrl)
    fun secureTokenBaseUrlOrNull(): String? = gated(secureTokenBaseUrl)
    fun webSocketUrlOrNull(): String? = gated(webSocketUrl)
    fun isUiTestRun(): Boolean = BuildConfig.DEBUG && isUiTest
    fun seededRefreshTokenOrNull(): String? = gated(seededRefreshToken)
    fun seededUidOrNull(): String? = gated(seededUid)
    fun animationsDisabled(): Boolean = BuildConfig.DEBUG && disableAnimations

    /** Clears every override (used by tests between runs). */
    fun reset() {
        apiBaseUrl = null
        identityBaseUrl = null
        secureTokenBaseUrl = null
        webSocketUrl = null
        isUiTest = false
        seededRefreshToken = null
        seededUid = null
        disableAnimations = false
    }
}
