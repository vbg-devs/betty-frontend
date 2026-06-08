@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/** `users.User` (api-contract.md §2). `id` is a Firebase UID **string**. */
@Serializable
data class UserProfile(
    val id: String,
    val email: String = "",
    val name: String = "",
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("firebase_image_url") val firebaseImageUrl: String? = null,
    val country: String? = null,
    @SerialName("is_admin") val isAdmin: Boolean = false,
    @SerialName("created_at") val createdAt: Instant? = null,
    @SerialName("updated_at") val updatedAt: Instant? = null,
)

/** `/countries` row. */
@Serializable
data class Country(
    val code: String,
    val name: String,
    @SerialName("flag_emoji") val flagEmoji: String? = null,
)
