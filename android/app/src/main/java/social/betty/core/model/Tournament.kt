@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/**
 * `tournaments.Tournament`. `pools`/`games` are **null** in `GET /tournaments` and populated
 * (as flat sibling arrays) in `GET /tournament/:id` — games reference pools via `pool_id`;
 * there is no `pool.games` / `game.pool` nesting on the wire (client-side joins only).
 */
@Serializable
data class Tournament(
    val id: Int,
    val name: String,
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("start_date") val startDate: Instant? = null,
    @SerialName("end_date") val endDate: Instant? = null,
    @SerialName("category_id") val categoryId: Int = 0,
    val pools: List<Pool> = emptyList(),
    val games: List<Game> = emptyList(),
)

@Serializable
data class Pool(
    val id: Int,
    @SerialName("tournament_id") val tournamentId: Int = 0,
    val name: String,
)

@Serializable
data class Game(
    val id: Int,
    @SerialName("tournament_id") val tournamentId: Int = 0,
    @SerialName("pool_id") val poolId: Int = 0,
    @SerialName("home_team_id") val homeTeamId: Int = 0,
    @SerialName("away_team_id") val awayTeamId: Int = 0,
    @SerialName("home_team_score") val homeTeamScore: Int = 0,
    @SerialName("away_team_score") val awayTeamScore: Int = 0,
    @SerialName("start_date") val startDate: Instant? = null,
    @SerialName("updated_at") val updatedAt: Instant? = null,
    val status: Int? = null,
) {
    /** `status == 1` is finished; anything else (incl. null) is not finished. */
    val isFinished: Boolean get() = status == 1
}

@Serializable
data class Team(
    val id: Int,
    @SerialName("tournament_id") val tournamentId: Int = 0,
    @SerialName("image_url") val imageUrl: String? = null,
    val name: String,
    @SerialName("is_placeholder") val isPlaceholder: Boolean = false,
)

@Serializable
data class Category(val id: Int, val name: String)

@Serializable
data class Arena(
    val id: Int,
    val name: String,
    val country: String = "",
    val city: String = "",
    val capacity: Int = 0,
    @SerialName("image_url") val imageUrl: String = "",
)
