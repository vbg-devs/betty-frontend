package social.betty.core.net

/**
 * Network/API failure taxonomy. Mirrors the iOS `APIError`: feature code branches on
 * [Status.code] for the per-endpoint status meanings documented in api-contract.md
 * (404/409/403/423/413/415/503/410/401, …).
 */
sealed class ApiError(message: String?, cause: Throwable? = null) : Exception(message, cause) {

    /** No signed-in session — thrown before any network I/O (matches web `authFetch`). */
    data object NotAuthenticated : ApiError("Not authenticated") {
        private fun readResolve(): Any = NotAuthenticated
    }

    /** Non-2xx HTTP response. [serverMessage] is the `{"error": "..."}` body when present. */
    data class Status(
        val code: Int,
        val body: String? = null,
        val serverMessage: String? = null,
    ) : ApiError("HTTP $code${serverMessage?.let { ": $it" } ?: ""}")

    /** Transport failure (no response, timeout, DNS, socket). */
    data class Network(val reason: Throwable) : ApiError(reason.message ?: "Network error", reason)

    /** Body did not decode to the expected shape. */
    data class Decoding(val reason: Throwable) : ApiError("Decoding error: ${reason.message}", reason)

    val statusCode: Int? get() = (this as? Status)?.code

    fun isStatus(vararg codes: Int): Boolean = statusCode?.let { it in codes } ?: false
}
