package social.betty.core.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * An authenticated Firebase session. The refresh token is persisted (encrypted); the ID
 * token + computed [expiresAt] live in memory and are refreshed proactively when < 5 min
 * of life remain (data-layer.md §3.2). Provider profile hints prefill complete-profile.
 */
data class AuthSession(
    val uid: String,
    val idToken: String,
    val refreshToken: String,
    val expiresAt: Instant,
    val email: String? = null,
    val displayName: String? = null,
    val photoUrl: String? = null,
    val isNewUser: Boolean = false,
)

/** Identity Toolkit error code (`message` field of the 400 envelope), mapped to UI copy. */
class AuthException(val code: String, val raw: String? = null) : Exception(code) {
    val friendlyMessage: String = when (code) {
        "INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD" ->
            "Wrong email or password."
        "USER_DISABLED" -> "This account has been disabled."
        "TOO_MANY_ATTEMPTS_TRY_LATER" -> "Too many attempts. Try again later."
        "EMAIL_EXISTS" -> "An account with this email already exists."
        "OPERATION_NOT_ALLOWED" -> "Email sign-in is not enabled."
        "INVALID_IDP_RESPONSE" -> "Sign-in failed. Please try again."
        "TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND" -> "Your session expired. Please sign in again."
        else -> code.split("_").joinToString(" ") { it.lowercase() }.replaceFirstChar { it.uppercase() }
    }

    /** Refresh failures that force a full sign-out. */
    val forcesSignOut: Boolean
        get() = code in setOf("TOKEN_EXPIRED", "USER_DISABLED", "USER_NOT_FOUND", "INVALID_REFRESH_TOKEN")
}

@Serializable
internal data class IdentityResponse(
    val localId: String? = null,
    val idToken: String? = null,
    val refreshToken: String? = null,
    val expiresIn: String? = null,
    val email: String? = null,
    val displayName: String? = null,
    val photoUrl: String? = null,
    val fullName: String? = null,
    val isNewUser: Boolean = false,
    val needConfirmation: Boolean = false,
)

@Serializable
internal data class SecureTokenResponse(
    @SerialName("access_token") val accessToken: String? = null,
    @SerialName("expires_in") val expiresIn: String? = null,
    @SerialName("refresh_token") val refreshToken: String? = null,
    @SerialName("id_token") val idToken: String? = null,
    @SerialName("user_id") val userId: String? = null,
)

@Serializable
internal data class IdentityErrorEnvelope(val error: IdentityError? = null)

@Serializable
internal data class IdentityError(val code: Int = 0, val message: String = "")
