package social.betty.app

import android.net.Uri
import social.betty.core.auth.GoogleOAuth

/**
 * Bridges the Google sign-in Custom Tab round-trip. [AuthScreen] starts the PKCE flow and
 * stashes the [GoogleOAuth.PendingAuth] here; the OAuth redirect (the reversed-client-id
 * scheme) re-enters [MainActivity], which calls [complete] to exchange the code for a Google
 * ID token, sign in via Firebase `signInWithIdp`, and resume the app. Mirrors the iOS
 * `ASWebAuthenticationSession` flow.
 */
object GoogleSignInCoordinator {
    @Volatile
    private var pending: GoogleOAuth.PendingAuth? = null

    fun begin(auth: GoogleOAuth.PendingAuth) {
        pending = auth
    }

    /** True for the OAuth redirect URI while a sign-in is in flight. */
    fun matches(uri: Uri): Boolean =
        pending != null && uri.scheme == AppConfig.googleOAuthRedirectScheme

    /**
     * Completes the redirect: validates state, exchanges the code, and signs in. Returns true
     * on success. Surfaces a toast on cancel/failure.
     */
    suspend fun complete(uri: Uri, container: AppContainer, appState: AppState): Boolean {
        val auth = pending ?: return false
        pending = null

        val code = uri.getQueryParameter("code")
        val state = uri.getQueryParameter("state")
        if (code == null || state != auth.state) {
            // User cancelled or the response was tampered with — silently return to auth.
            return false
        }
        return try {
            val googleIdToken = GoogleOAuth.exchange(
                http = container.httpClient,
                clientId = AppConfig.GOOGLE_OAUTH_CLIENT_ID,
                code = code,
                codeVerifier = auth.codeVerifier,
                redirectUri = auth.redirectUri,
            )
            val session = container.authClient.signInWithIdp(GoogleOAuth.idpPostBody(googleIdToken))
            container.sessionManager.signIn(session)
            appState.onInteractiveSignIn()
            true
        } catch (e: Exception) {
            container.notify.error("Google sign-in failed. Please try again or use email.")
            false
        }
    }
}
