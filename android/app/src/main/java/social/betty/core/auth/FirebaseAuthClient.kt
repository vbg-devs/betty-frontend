package social.betty.core.auth

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import social.betty.app.AppConfig
import social.betty.core.net.ApiError
import social.betty.core.net.BettyJson
import java.time.Instant

/**
 * Firebase Auth via Identity Toolkit + securetoken REST (no Firebase SDK), matching
 * api-contract.md §1. Base URLs come from [AppConfig] so the e2e mock backend can intercept
 * them. Identity Toolkit errors are 400 with `{"error":{"message":"<CODE>"}}` → [AuthException].
 */
class FirebaseAuthClient(
    private val http: OkHttpClient,
    private val json: Json = BettyJson,
) {
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun signInWithPassword(email: String, password: String): AuthSession =
        identity("accounts:signInWithPassword", credentialBody(email, password))

    suspend fun signUp(email: String, password: String): AuthSession =
        identity("accounts:signUp", credentialBody(email, password))

    /**
     * Federated sign-in for Apple/Google. [postBody] is the urlencoded
     * `id_token=<jwt>&providerId=<apple.com|google.com>[&nonce=<raw>]` string.
     */
    suspend fun signInWithIdp(
        postBody: String,
        requestUri: String = "https://${AppConfig.FIREBASE_PROJECT_ID}.firebaseapp.com",
    ): AuthSession {
        val body = buildJsonObject {
            put("postBody", postBody)
            put("requestUri", requestUri)
            put("returnSecureToken", true)
            put("returnIdpCredential", true)
        }
        return identity("accounts:signInWithIdp", body)
    }

    private fun credentialBody(email: String, password: String): JsonObject = buildJsonObject {
        put("email", email)
        put("password", password)
        put("returnSecureToken", true)
    }

    private suspend fun identity(method: String, body: JsonObject): AuthSession =
        withContext(Dispatchers.IO) {
            val url = "${AppConfig.identityBaseUrl}/v1/$method".toHttpUrl().newBuilder()
                .addQueryParameter("key", AppConfig.FIREBASE_API_KEY)
                .build()
            val request = Request.Builder()
                .url(url)
                .post(body.toString().toRequestBody(jsonMedia))
                .build()
            val (status, payload) = call(request)
            if (status !in 200..299) throw parseIdentityError(payload)
            val response = decode<IdentityResponse>(payload)
            response.toSession()
        }

    suspend fun refresh(refreshToken: String): AuthSession = withContext(Dispatchers.IO) {
        val url = "${AppConfig.secureTokenBaseUrl}/v1/token".toHttpUrl().newBuilder()
            .addQueryParameter("key", AppConfig.FIREBASE_API_KEY)
            .build()
        val form = FormBody.Builder()
            .add("grant_type", "refresh_token")
            .add("refresh_token", refreshToken)
            .build()
        val request = Request.Builder().url(url).post(form).build()
        val (status, payload) = call(request)
        if (status !in 200..299) throw parseIdentityError(payload)
        val response = decode<SecureTokenResponse>(payload)
        AuthSession(
            uid = response.userId.orEmpty(),
            idToken = response.idToken ?: response.accessToken.orEmpty(),
            refreshToken = response.refreshToken ?: refreshToken,
            expiresAt = expiry(response.expiresIn),
            isNewUser = false,
        )
    }

    private fun call(request: Request): Pair<Int, String> = try {
        http.newCall(request).execute().use { it.code to it.body?.string().orEmpty() }
    } catch (e: Exception) {
        throw ApiError.Network(e)
    }

    private inline fun <reified T> decode(payload: String): T = try {
        json.decodeFromString<T>(payload)
    } catch (e: Exception) {
        throw ApiError.Decoding(e)
    }

    private fun parseIdentityError(payload: String): AuthException {
        val code = runCatching { json.decodeFromString<IdentityErrorEnvelope>(payload).error?.message }
            .getOrNull()
            ?.substringBefore(" ") // "WEAK_PASSWORD : ..." → "WEAK_PASSWORD"
            ?: "AUTH_ERROR"
        return AuthException(code, payload.take(300))
    }

    private fun IdentityResponse.toSession(): AuthSession {
        if (idToken.isNullOrEmpty() || refreshToken.isNullOrEmpty() || localId.isNullOrEmpty()) {
            throw AuthException("INVALID_IDP_RESPONSE")
        }
        return AuthSession(
            uid = localId,
            idToken = idToken,
            refreshToken = refreshToken,
            expiresAt = expiry(expiresIn),
            email = email,
            displayName = displayName ?: fullName,
            photoUrl = photoUrl,
            isNewUser = isNewUser,
        )
    }

    private fun expiry(expiresIn: String?): Instant =
        Instant.now().plusSeconds(expiresIn?.toLongOrNull() ?: 3600L)
}
