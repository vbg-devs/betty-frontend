@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/**
 * `bets.Bet` (api-contract.md §2). `user_id` is a string. `user_points` is null until the
 * game is evaluated. `is_universal` is request-only (always false on reads). The `POST /bet`
 * 200 echo has `id: 0` and zero timestamps — re-fetch to learn the real id.
 */
@Serializable
data class Bet(
    val id: Int = 0,
    @SerialName("user_id") val userId: String = "",
    @SerialName("game_id") val gameId: Int,
    @SerialName("group_id") val groupId: Int,
    @SerialName("user_points") val userPoints: Int? = null,
    @SerialName("home_team_score") val homeTeamScore: Int = 0,
    @SerialName("away_team_score") val awayTeamScore: Int = 0,
    @SerialName("is_universal") val isUniversal: Boolean = false,
    @SerialName("processed_at") val processedAt: Instant? = null,
    @SerialName("created_at") val createdAt: Instant? = null,
    @SerialName("updated_at") val updatedAt: Instant? = null,
) {
    val isProcessed: Boolean get() = processedAt != null
}
