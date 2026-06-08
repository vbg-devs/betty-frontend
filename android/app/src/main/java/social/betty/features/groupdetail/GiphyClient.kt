package social.betty.features.groupdetail

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import social.betty.app.AppConfig
import java.util.concurrent.TimeUnit

/** One Giphy search hit — only the original-rendition URL is used (web parity). */
data class GiphyImage(val id: String, val originalUrl: String)

/**
 * Minimal Giphy REST search for the chat GIF mode (web `MemeBoard` parity) — plain HTTPS,
 * no SDK. `GET https://api.giphy.com/v1/gifs/search?api_key=…&q=…&limit=…`.
 */
class GiphyClient(
    private val apiKey: String = AppConfig.GIPHY_API_KEY,
    private val baseUrl: String = "https://api.giphy.com",
) {
    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun search(query: String, limit: Int = 10): List<GiphyImage> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/v1/gifs/search".toHttpUrl().newBuilder()
            .addQueryParameter("api_key", apiKey)
            .addQueryParameter("q", query)
            .addQueryParameter("limit", limit.toString())
            .build()
        val request = Request.Builder().url(url).get().build()
        http.newCall(request).execute().use { resp ->
            if (!resp.isSuccessful) return@withContext emptyList()
            val body = resp.body?.string().orEmpty()
            val root = json.parseToJsonElement(body).jsonObject
            val data = root["data"]?.jsonArray ?: return@withContext emptyList()
            data.mapNotNull { element ->
                val obj = element.jsonObject
                val id = obj["id"]?.jsonPrimitive?.content ?: return@mapNotNull null
                val original = obj["images"]?.jsonObject?.get("original")?.jsonObject
                val gifUrl = original?.get("url")?.jsonPrimitive?.content ?: return@mapNotNull null
                GiphyImage(id = id, originalUrl = gifUrl)
            }
        }
    }
}
