@file:UseSerializers(InstantSerializer::class)

package social.betty.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.json.JsonElement
import java.time.Instant

/**
 * WebSocket envelope (api-contract.md §4): `{"type": <string>, "message": <any|null>}`.
 * Event types are the pubsub subjects minus the `betty_events.` prefix. `message` shape
 * varies per type — kept as a raw [JsonElement] and decoded on demand by feed rows.
 */
@Serializable
data class WebSocketEnvelope(
    val type: String,
    val message: JsonElement? = null,
)

/** Activity-feed ring-buffer item (data-layer.md §5.7). `id` is a client-assigned counter. */
data class ActivityMessage(
    val id: Long,
    val type: String,
    val message: JsonElement?,
    val timestamp: Instant,
)

object WebSocketEventType {
    const val PING = "ping"
    const val USER_REGISTER = "user_register"
    const val BET_PLACED = "bet_placed"
    const val BET_UPDATED = "bet_updated"
    const val GROUP_JOINED = "group_joined"
    const val GROUP_LEFT = "group_left"
    const val GROUP_CREATED = "group_created"
    const val GROUP_VISIBILITY_CHANGED = "group_visibility_changed"
    const val EVALUATE_GAME = "evaluate_game"
    const val USER_EXACT_SCORE = "user_exact_score"
    const val GAME_STARTING_SOON = "game_starting_soon"
}

/** `evaluate_game` payload — "full time / refresh scores". */
@Serializable
data class EvaluateGamePayload(
    @SerialName("game_id") val gameId: Int,
    @SerialName("home_team_score") val homeTeamScore: Int = 0,
    @SerialName("away_team_score") val awayTeamScore: Int = 0,
)

/** `group_joined` payload. */
@Serializable
data class GroupJoinedPayload(
    val group: GroupRef? = null,
    val who: String? = null,
) {
    @Serializable
    data class GroupRef(val id: Int, val name: String = "")
}

/** `group_visibility_changed` payload. */
@Serializable
data class VisibilityChangedPayload(
    @SerialName("group_id") val groupId: Int,
    @SerialName("public_at") val publicAt: Instant? = null,
)

/** `user_exact_score` payload. */
@Serializable
data class ExactScorePayload(
    @SerialName("game_id") val gameId: Int,
    @SerialName("user_ids") val userIds: List<String> = emptyList(),
)
