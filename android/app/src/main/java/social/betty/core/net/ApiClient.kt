package social.betty.core.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody

/** A valid Firebase ID token, refreshing if needed; null when unauthenticated. */
fun interface TokenProvider {
    suspend fun validToken(): String?
}

data class ApiResponse(val status: Int, val bodyString: String) {
    val isSuccess: Boolean get() = status in 200..299
}

/**
 * Low-level HTTP edge. Prefixes the (override-aware) API base, attaches a fresh `Bearer`
 * token on every authenticated call (throwing [ApiError.NotAuthenticated] before any I/O
 * when signed out — mirrors web `authFetch`), and never throws on HTTP status. Typed
 * decoding and per-endpoint status handling live in [BettyApi].
 */
class ApiClient(
    private val http: OkHttpClient,
    private val tokenProvider: TokenProvider,
    private val baseUrlProvider: () -> String,
    val json: Json = BettyJson,
) {
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun execute(
        method: String,
        path: String,
        query: Map<String, String?> = emptyMap(),
        jsonBody: String? = null,
        authenticated: Boolean = true,
    ): ApiResponse = withContext(Dispatchers.IO) {
        val urlBuilder = (baseUrlProvider() + path).toHttpUrl().newBuilder()
        query.forEach { (k, v) -> if (!v.isNullOrEmpty() || v == "0") urlBuilder.addQueryParameter(k, v) }

        val builder = Request.Builder().url(urlBuilder.build())
        if (authenticated) {
            val token = tokenProvider.validToken() ?: throw ApiError.NotAuthenticated
            builder.header("Authorization", "Bearer $token")
        }

        val needsBody = method == "POST" || method == "PUT" || method == "PATCH"
        val body: RequestBody? = when {
            jsonBody != null -> jsonBody.toRequestBody(jsonMedia)
            needsBody -> "".toRequestBody(jsonMedia)
            else -> null
        }
        builder.method(method, body)

        try {
            http.newCall(builder.build()).execute().use { resp ->
                ApiResponse(resp.code, resp.body?.string().orEmpty())
            }
        } catch (e: ApiError) {
            throw e
        } catch (e: Exception) {
            throw ApiError.Network(e)
        }
    }

    /** Raw presigned upload to R2 (no auth). Returns the HTTP status. */
    suspend fun rawUpload(
        url: String,
        method: String,
        headers: Map<String, List<String>>,
        contentType: String,
        bytes: ByteArray,
    ): Int = withContext(Dispatchers.IO) {
        val builder = Request.Builder().url(url.toHttpUrl())
        headers.forEach { (name, values) ->
            // Content-Length / Host are managed by OkHttp; the rest are baked into the signature.
            if (!name.equals("Content-Length", true) && !name.equals("Host", true)) {
                values.forEach { builder.addHeader(name, it) }
            }
        }
        val body = bytes.toRequestBody(contentType.toMediaType())
        builder.method(method.ifBlank { "PUT" }, body)
        try {
            http.newCall(builder.build()).execute().use { it.code }
        } catch (e: Exception) {
            throw ApiError.Network(e)
        }
    }

    /** Throws an [ApiError.Status] carrying any `{"error": "..."}` server message. */
    fun statusError(resp: ApiResponse): ApiError.Status {
        val message = runCatching {
            json.parseToJsonElement(resp.bodyString).jsonObject["error"]?.jsonPrimitive?.content
        }.getOrNull()
        return ApiError.Status(resp.status, resp.bodyString.take(500), message)
    }
}
