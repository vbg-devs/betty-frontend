@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/**
 * Message-board (group chat) message. `reactions` is `[]` on `GET /messageboard/:groupid`
 * but **null** in the `POST /messageboard` 201 echo — coerced to empty here.
 */
@Serializable
data class GroupMessage(
    val id: Int,
    @SerialName("group_id") val groupId: Int,
    @SerialName("user_id") val userId: String,
    @SerialName("image_url") val imageUrl: String? = null,
    val body: String? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
    val reactions: List<MessageReaction> = emptyList(),
)

@Serializable
data class MessageReaction(
    @SerialName("user_id") val userId: String,
    @SerialName("emoji_id") val emojiId: String,
    @SerialName("created_at") val createdAt: Instant? = null,
)

/** Canonical reaction set offered in the chat composer (one per user per message). */
object Reactions {
    val palette = listOf("👍", "❤️", "😂", "🔥", "🎉", "😮", "😢", "👀")
}
