@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/**
 * `groups.Group` (api-contract.md §2). Quirk: `is_public` is **always false on reads**
 * (`db:"-"`) — derive publicness from [publicAt] != null. The bet-mode field is `mode`
 * here but `bet_mode` on [GroupPlacement]/[PublicGroupItem].
 */
@Serializable
data class Group(
    val id: Int,
    val name: String,
    @SerialName("tournament_id") val tournamentId: Int,
    @SerialName("tournament_name") val tournamentName: String? = null,
    @SerialName("tournament_image_url") val tournamentImageUrl: String? = null,
    @SerialName("header_image_url") val headerImageUrl: String? = null,
    @SerialName("invite_code") val inviteCode: String = "",
    @SerialName("invite_url") val inviteUrl: String? = null,
    @SerialName("welcome_message") val welcomeMessage: String? = null,
    val description: String? = null,
    @SerialName("correct_team_points") val correctTeamPoints: Int = 0,
    @SerialName("exact_result_points") val exactResultPoints: Int = 0,
    @SerialName("allow_sneak_peek") val allowSneakPeek: Boolean = false,
    @SerialName("group_play_deadline") val groupPlayDeadline: Instant? = null,
    val mode: Int = 0,
    /** Boosters per user in this group. `0` disables boosters; defaults to `0` on new groups. */
    @SerialName("boost_count") val boostCount: Int = 0,
    /** Multiplier when a booster is applied. Default `2`; ignored when [boostCount] is 0. */
    @SerialName("boost_multiplier") val boostMultiplier: Int = 2,
    @SerialName("public_at") val publicAt: Instant? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
    @SerialName("updated_at") val updatedAt: Instant? = null,
    val members: List<GroupMember> = emptyList(),
) {
    val isPublic: Boolean get() = publicAt != null
}

/** `groups.Member`. `access_level`: 0 author, 1 admin, 2 participant. `user_id` is a string. */
@Serializable
data class GroupMember(
    @SerialName("user_id") val userId: String,
    val name: String? = null,
    val nickname: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    val score: Int = 0,
    @SerialName("normalized_score") val normalizedScore: Double? = null,
    @SerialName("access_level") val accessLevel: Int = 0,
)

/** `/user/:id/groups` placements payload. `placement` is 1-based competition ranking. */
@Serializable
data class GroupPlacement(
    val id: Int,
    val name: String,
    @SerialName("tournament_id") val tournamentId: Int,
    @SerialName("tournament_name") val tournamentName: String? = null,
    @SerialName("tournament_image_url") val tournamentImageUrl: String? = null,
    @SerialName("header_image_url") val headerImageUrl: String? = null,
    @SerialName("bet_mode") val betMode: Int = 0,
    @SerialName("public_at") val publicAt: Instant? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
    val score: Int = 0,
    @SerialName("normalized_score") val normalizedScore: Double = 0.0,
    val placement: Int = 0,
    @SerialName("member_count") val memberCount: Int = 0,
)

@Serializable
data class UserGroupsResponse(
    val user: UserProfile,
    val groups: List<GroupPlacement> = emptyList(),
)

/** `/groups/public` item — distinct DTO with denormalized tournament fields. */
@Serializable
data class PublicGroupItem(
    val id: Int,
    val name: String,
    val description: String? = null,
    @SerialName("tournament_id") val tournamentId: Int,
    @SerialName("tournament_name") val tournamentName: String? = null,
    @SerialName("tournament_image_url") val tournamentImageUrl: String? = null,
    @SerialName("header_image_url") val headerImageUrl: String? = null,
    @SerialName("correct_team_points") val correctTeamPoints: Int = 0,
    @SerialName("exact_result_points") val exactResultPoints: Int = 0,
    @SerialName("allow_sneak_peek") val allowSneakPeek: Boolean = false,
    @SerialName("bet_mode") val betMode: Int = 0,
    @SerialName("group_play_deadline") val groupPlayDeadline: Instant? = null,
    @SerialName("boost_count") val boostCount: Int = 0,
    @SerialName("boost_multiplier") val boostMultiplier: Int = 2,
    @SerialName("public_at") val publicAt: Instant? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
    @SerialName("member_count") val memberCount: Int = 0,
    @SerialName("is_member") val isMember: Boolean = false,
)

@Serializable
data class PublicGroupListResponse(
    val items: List<PublicGroupItem> = emptyList(),
    @SerialName("next_cursor") val nextCursor: String = "",
)

/** `GET /group/:code` invite preview. */
@Serializable
data class GroupPeek(
    val id: Int,
    val name: String,
    @SerialName("tournament_id") val tournamentId: Int,
    @SerialName("tournament_name") val tournamentName: String? = null,
    @SerialName("tournament_image_url") val tournamentImageUrl: String? = null,
    @SerialName("header_image_url") val headerImageUrl: String? = null,
    @SerialName("invite_code") val inviteCode: String = "",
)
