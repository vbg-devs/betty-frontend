@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

@Serializable
data class Announcement(
    val id: Int,
    @SerialName("user_id") val userId: String,
    val title: String,
    val body: String,
    val category: String,
    val cta: String? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
)

@Serializable
data class FeatureRequest(
    val id: Int = 0,
    @SerialName("user_id") val userId: String = "",
    val description: String,
    @SerialName("created_at") val createdAt: Instant? = null,
)

/**
 * `storage.PresignedUpload`. `headers` is Go `http.Header` (map of string → array of
 * strings). Upload flow: PUT raw bytes to [uploadUrl] with exactly the declared Content-Type
 * and byte count (baked into the signature), then commit [publicUrl] via the matching endpoint.
 */
@Serializable
data class PresignedUpload(
    val key: String = "",
    @SerialName("upload_url") val uploadUrl: String,
    val method: String = "PUT",
    val headers: Map<String, List<String>> = emptyMap(),
    @SerialName("public_url") val publicUrl: String,
    @SerialName("expires_at") val expiresAt: Instant? = null,
)
