package social.betty.app

/**
 * Resolved runtime configuration. Production endpoints by default; the DEBUG-only
 * [LaunchOverrides] redirect them at the in-process mock backend during e2e tests.
 *
 * Firebase project `betty-f676d`, Web API key from the spec (api-contract.md §1). The
 * Google OAuth client id is a placeholder documented in android/README.md.
 */
object AppConfig {
    const val FIREBASE_API_KEY = "AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg"
    const val FIREBASE_PROJECT_ID = "betty-f676d"

    // Google sign-in via Custom Tabs PKCE (same flow + same Firebase project OAuth client as
    // iOS — `ios/project.yml` GoogleOAuthClientID). The reversed-client-id scheme is the
    // redirect; it MUST also be declared as an intent-filter on MainActivity in the manifest.
    const val GOOGLE_OAUTH_CLIENT_ID =
        "812539187075-1ijbvedesug3dl8mtbvfnoh0rrvcblpe.apps.googleusercontent.com"

    /** Reversed-client-id custom scheme used for the OAuth redirect (matches the manifest). */
    val googleOAuthRedirectScheme: String
        get() = "com.googleusercontent.apps." +
            GOOGLE_OAUTH_CLIENT_ID.removeSuffix(".apps.googleusercontent.com")

    private const val PROD_API = "https://api.betty.social/api/v1"
    private const val PROD_IDENTITY = "https://identitytoolkit.googleapis.com"
    private const val PROD_SECURETOKEN = "https://securetoken.googleapis.com"
    private const val PROD_WS = "wss://api.betty.social/ws"

    val apiBaseUrl: String get() = LaunchOverrides.apiBaseUrlOrNull() ?: PROD_API
    val identityBaseUrl: String get() = LaunchOverrides.identityBaseUrlOrNull() ?: PROD_IDENTITY
    val secureTokenBaseUrl: String get() = LaunchOverrides.secureTokenBaseUrlOrNull() ?: PROD_SECURETOKEN
    val webSocketUrl: String get() = LaunchOverrides.webSocketUrlOrNull() ?: PROD_WS

    const val INVITE_LINK_PREFIX = "https://betty.social/dashboard/groups/join/"
    const val GIPHY_API_KEY = "EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r"
}
