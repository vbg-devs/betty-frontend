package social.betty.core.auth

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import social.betty.core.net.ApiError
import social.betty.core.net.BettyJson
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Google sign-in via a Custom Tabs PKCE flow (the `ASWebAuthenticationSession` analogue,
 * api-contract.md §1.3). Core provides the crypto + token exchange; the Auth feature opens
 * the Custom Tab and captures the redirect (custom scheme = reversed client id).
 *
 * The OAuth client id is configured in [social.betty.app.AppConfig.GOOGLE_OAUTH_CLIENT_ID]
 * (placeholder until provisioned, like the iOS `GoogleOAuthClientID`).
 */
object GoogleOAuth {
    private const val AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
    private const val TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

    data class PendingAuth(
        val authUrl: String,
        val codeVerifier: String,
        val redirectUri: String,
        val state: String,
    )

    fun begin(clientId: String): PendingAuth {
        val verifier = randomUrlSafe(64)
        val challenge = base64Url(sha256(verifier.toByteArray()))
        val state = randomUrlSafe(16)
        val redirectUri = "${reversedScheme(clientId)}:/oauth2redirect"
        val authUrl = "$AUTH_ENDPOINT?" + listOf(
            "client_id" to clientId,
            "redirect_uri" to redirectUri,
            "response_type" to "code",
            "scope" to "openid email profile",
            "code_challenge" to challenge,
            "code_challenge_method" to "S256",
            "state" to state,
        ).joinToString("&") { (k, v) -> "$k=${urlEncode(v)}" }
        return PendingAuth(authUrl, verifier, redirectUri, state)
    }

    /** Exchanges the authorization code for a Google ID token. */
    suspend fun exchange(
        http: OkHttpClient,
        clientId: String,
        code: String,
        codeVerifier: String,
        redirectUri: String,
        json: Json = BettyJson,
    ): String = withContext(Dispatchers.IO) {
        val form = FormBody.Builder()
            .add("grant_type", "authorization_code")
            .add("code", code)
            .add("code_verifier", codeVerifier)
            .add("client_id", clientId)
            .add("redirect_uri", redirectUri)
            .build()
        val request = Request.Builder().url(TOKEN_ENDPOINT).post(form).build()
        val payload = try {
            http.newCall(request).execute().use { it.body?.string().orEmpty() }
        } catch (e: Exception) {
            throw ApiError.Network(e)
        }
        json.parseToJsonElement(payload).jsonObject["id_token"]?.jsonPrimitive?.content
            ?: throw AuthException("INVALID_IDP_RESPONSE", payload.take(200))
    }

    fun idpPostBody(googleIdToken: String): String = "id_token=$googleIdToken&providerId=google.com"

    /** `<num>-<hash>.apps.googleusercontent.com` → `com.googleusercontent.apps.<num>-<hash>`. */
    private fun reversedScheme(clientId: String): String {
        val prefix = clientId.removeSuffix(".apps.googleusercontent.com")
        return "com.googleusercontent.apps.$prefix"
    }

    private fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)

    private fun base64Url(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

    private fun randomUrlSafe(bytes: Int): String {
        val buf = ByteArray(bytes)
        SecureRandom().nextBytes(buf)
        return base64Url(buf)
    }

    private fun urlEncode(value: String): String =
        java.net.URLEncoder.encode(value, "UTF-8")
}
