@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/** Small typed response envelopes returned by mutation endpoints. */

@Serializable
data class GroupIdResponse(@SerialName("group_id") val groupId: Int)

@Serializable
data class CodeResponse(val code: String)

@Serializable
data class PublicAtResponse(@SerialName("public_at") val publicAt: Instant? = null)

@Serializable
data class NicknameResponse(val nickname: String? = null)

@Serializable
data class ImageUrlResponse(@SerialName("image_url") val imageUrl: String? = null)

@Serializable
data class HeaderImageUrlResponse(@SerialName("header_image_url") val headerImageUrl: String? = null)
