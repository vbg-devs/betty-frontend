package social.betty.features.activity

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import social.betty.core.model.ActivityMessage
import social.betty.core.model.EvaluateGamePayload
import social.betty.core.model.ExactScorePayload
import social.betty.core.model.Game
import social.betty.core.model.GroupJoinedPayload
import social.betty.core.model.Team
import social.betty.core.model.VisibilityChangedPayload
import social.betty.core.model.WebSocketEventType
import social.betty.core.net.BettyJson
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.TeamLogo

// ---------------------------------------------------------------------------
// Accent helpers
// ---------------------------------------------------------------------------

private enum class FeedAccent { ORANGE, YELLOW, GREEN, CREAM }

private fun FeedAccent.toColor(accentPositive: Color): Color = when (this) {
    FeedAccent.ORANGE -> Palette.orange
    FeedAccent.YELLOW -> Palette.yellow
    FeedAccent.GREEN -> accentPositive
    FeedAccent.CREAM -> Color(0xFFFFFAEB).copy(alpha = 0.78f)
}

private data class RowMeta(
    val kicker: String,
    val accent: FeedAccent,
)

private fun rowMeta(type: String): RowMeta = when (type) {
    WebSocketEventType.BET_PLACED -> RowMeta("● NEW BET", FeedAccent.ORANGE)
    WebSocketEventType.BET_UPDATED -> RowMeta("● BET UPDATED", FeedAccent.ORANGE)
    WebSocketEventType.BOOSTER_APPLIED -> RowMeta("🚀 BOOSTER", FeedAccent.ORANGE)
    WebSocketEventType.GAME_STARTING_SOON -> RowMeta("● KICKING OFF", FeedAccent.YELLOW)
    WebSocketEventType.EVALUATE_GAME -> RowMeta("★ FULL TIME", FeedAccent.CREAM)
    WebSocketEventType.USER_EXACT_SCORE -> RowMeta("★ EXACT SCORE", FeedAccent.GREEN)
    WebSocketEventType.GROUP_JOINED -> RowMeta("● JOINED GROUP", FeedAccent.GREEN)
    WebSocketEventType.GROUP_LEFT -> RowMeta("● LEFT GROUP", FeedAccent.CREAM)
    WebSocketEventType.GROUP_CREATED -> RowMeta("★ NEW GROUP", FeedAccent.ORANGE)
    WebSocketEventType.GROUP_VISIBILITY_CHANGED -> RowMeta("● VISIBILITY", FeedAccent.YELLOW)
    WebSocketEventType.USER_REGISTER -> RowMeta("★ WELCOME", FeedAccent.GREEN)
    else -> RowMeta(type.uppercase(), FeedAccent.CREAM)
}

// ---------------------------------------------------------------------------
// Per-message row
// ---------------------------------------------------------------------------

/**
 * Renders one activity-feed entry: left accent bar, icon circle, kicker, type-specific body.
 * Port of iOS `ActivityEventRow` / web row variants (components.md §7).
 */
@Composable
fun ActivityRow(
    message: ActivityMessage,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    groupNameById: (Int) -> String?,
    /** Resolves a `(groupId, userId)` pair to a display name (nickname || name). */
    memberDisplayName: (Int, String) -> String? = { _, _ -> null },
    currentUserId: String?,
    onLoadGame: suspend (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val meta = rowMeta(message.type)
    val colors = BettyTheme.colors
    val accentColor = meta.accent.toColor(colors.accentPositive)

    InsetPanel(
        accent = accentColor,
        modifier = modifier
            .fillMaxWidth()
            .testTag("activity-row"),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            KickerText(text = meta.kicker, color = accentColor)
            FeedBody(
                message = message,
                gameById = gameById,
                teamById = teamById,
                groupNameById = groupNameById,
                memberDisplayName = memberDisplayName,
                currentUserId = currentUserId,
                onLoadGame = onLoadGame,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Body dispatch
// ---------------------------------------------------------------------------

@Composable
private fun FeedBody(
    message: ActivityMessage,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    groupNameById: (Int) -> String?,
    memberDisplayName: (Int, String) -> String?,
    currentUserId: String?,
    onLoadGame: suspend (Int) -> Unit,
) {
    when (message.type) {
        WebSocketEventType.BET_PLACED -> FeedBetItem(
            msg = message,
            update = false,
            gameById = gameById,
            teamById = teamById,
            onLoadGame = onLoadGame,
        )
        WebSocketEventType.BET_UPDATED -> FeedBetItem(
            msg = message,
            update = true,
            gameById = gameById,
            teamById = teamById,
            onLoadGame = onLoadGame,
        )
        WebSocketEventType.BOOSTER_APPLIED -> FeedBoosterItem(
            msg = message,
            gameById = gameById,
            teamById = teamById,
            memberDisplayName = memberDisplayName,
            onLoadGame = onLoadGame,
        )
        WebSocketEventType.GAME_STARTING_SOON -> FeedKickoffItem(
            msg = message,
            gameById = gameById,
            teamById = teamById,
            onLoadGame = onLoadGame,
        )
        WebSocketEventType.EVALUATE_GAME -> FeedResultItem(
            msg = message,
            gameById = gameById,
            teamById = teamById,
            onLoadGame = onLoadGame,
        )
        WebSocketEventType.USER_EXACT_SCORE -> FeedExactScoreItem(
            msg = message,
            currentUserId = currentUserId,
        )
        WebSocketEventType.GROUP_JOINED -> FeedGroupJoinedItem(msg = message)
        WebSocketEventType.GROUP_LEFT -> FeedPlainText("Someone just left a group")
        WebSocketEventType.GROUP_CREATED -> FeedPlainText("New group on Betty")
        WebSocketEventType.GROUP_VISIBILITY_CHANGED -> FeedVisibilityItem(
            msg = message,
            groupNameById = groupNameById,
        )
        WebSocketEventType.USER_REGISTER -> FeedWelcomeItem(msg = message)
        else -> FeedPlainText(message.type.uppercase())
    }
}

// ---------------------------------------------------------------------------
// Primitive helpers
// ---------------------------------------------------------------------------

@Composable
private fun FeedPlainText(text: String) {
    Text(
        text = text,
        style = BettyTheme.type.body,
        color = BettyTheme.colors.textPrimary,
    )
}

/** Tiny inline team logo pair: home - away. Only rendered when both teams are cached. */
@Composable
private fun FeedTeamLogos(homeTeamId: Int, awayTeamId: Int, teamById: (Int) -> Team?) {
    val home = teamById(homeTeamId)
    val away = teamById(awayTeamId)
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (home != null) {
            TeamLogo(url = home.imageUrl, name = home.name, size = 19.dp)
        }
        Text(
            text = " - ",
            style = BettyTheme.type.body,
            color = BettyTheme.colors.textSecondary,
        )
        if (away != null) {
            TeamLogo(url = away.imageUrl, name = away.name, size = 19.dp)
        }
    }
}

// ---------------------------------------------------------------------------
// Type-specific body composables (port of iOS / components.md §7.2–7.7)
// ---------------------------------------------------------------------------

/**
 * `bet_placed` / `bet_updated` (components.md §7.2). Renders nothing until the game is
 * cached; lazily triggers `onLoadGame` exactly once per unseen game id.
 */
@Composable
private fun FeedBetItem(
    msg: ActivityMessage,
    update: Boolean,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    onLoadGame: suspend (Int) -> Unit,
) {
    val gameId = runCatching {
        msg.message?.jsonObject?.get("game_id")?.jsonPrimitive?.int ?: 0
    }.getOrDefault(0)

    val game = if (gameId != 0) gameById(gameId) else null

    // Trigger lazy load — must be inside a real composable scope.
    LaunchedEffect(gameId) {
        if (gameId != 0 && gameById(gameId) == null) {
            onLoadGame(gameId)
        }
    }

    if (game != null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = if (update) "Someone updated their bet on" else "Someone placed a bet on",
                style = BettyTheme.type.body,
                color = BettyTheme.colors.textPrimary,
            )
            Spacer(Modifier.width(Space.xxs))
            FeedTeamLogos(
                homeTeamId = game.homeTeamId,
                awayTeamId = game.awayTeamId,
                teamById = teamById,
            )
        }
    }
    // Renders nothing until game is available (web parity).
}

/**
 * `booster_applied` — "🚀 **{user_name}** boosted **{home_team}** vs **{away_team}**".
 * Payload is the full `Bet` (echo shape). Lazily loads the game so team names are present;
 * renders nothing while pending. Actor name resolved from the group's members.
 */
@Composable
private fun FeedBoosterItem(
    msg: ActivityMessage,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    memberDisplayName: (Int, String) -> String?,
    onLoadGame: suspend (Int) -> Unit,
) {
    val payload = msg.message?.jsonObject
    val gameId = runCatching { payload?.get("game_id")?.jsonPrimitive?.int ?: 0 }.getOrDefault(0)
    val groupId = runCatching { payload?.get("group_id")?.jsonPrimitive?.int ?: 0 }.getOrDefault(0)
    val userId = runCatching { payload?.get("user_id")?.jsonPrimitive?.content ?: "" }.getOrDefault("")

    val game = if (gameId != 0) gameById(gameId) else null
    LaunchedEffect(gameId) {
        if (gameId != 0 && gameById(gameId) == null) {
            onLoadGame(gameId)
        }
    }

    if (game != null) {
        val home = teamById(game.homeTeamId)
        val away = teamById(game.awayTeamId)
        val actor = memberDisplayName(groupId, userId)?.takeIf { it.isNotEmpty() } ?: "Someone"
        val colors = BettyTheme.colors
        Text(
            text = buildAnnotatedString {
                append("🚀 ")
                withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(actor) }
                append(" boosted ")
                withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(home?.name ?: "") }
                append(" vs ")
                withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(away?.name ?: "") }
            },
            style = BettyTheme.type.body,
            color = colors.textPrimary,
        )
    }
}

/**
 * `game_starting_soon` (components.md §7.3). Uses the FIRST entry of the capital-G
 * `Games` array payload.
 */
@Composable
private fun FeedKickoffItem(
    msg: ActivityMessage,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    onLoadGame: suspend (Int) -> Unit,
) {
    // Payload: { "Games": [ { "id": <gameId> } ] }  (capital G per spec).
    val gameId = runCatching {
        msg.message?.jsonObject
            ?.get("Games")?.jsonArray
            ?.firstOrNull()?.jsonObject
            ?.get("id")?.jsonPrimitive?.int ?: 0
    }.getOrDefault(0)

    val game = if (gameId != 0) gameById(gameId) else null

    LaunchedEffect(gameId) {
        if (gameId != 0 && gameById(gameId) == null) {
            onLoadGame(gameId)
        }
    }

    if (game != null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Match is about to start",
                style = BettyTheme.type.body,
                color = BettyTheme.colors.textPrimary,
            )
            Spacer(Modifier.width(Space.xxs))
            FeedTeamLogos(
                homeTeamId = game.homeTeamId,
                awayTeamId = game.awayTeamId,
                teamById = teamById,
            )
        }
    }
}

/**
 * `evaluate_game` (components.md §7.4). Shows "Game evaluated" + final scores from the
 * cached game; blanks when scores are null.
 */
@Composable
private fun FeedResultItem(
    msg: ActivityMessage,
    gameById: (Int) -> Game?,
    teamById: (Int) -> Team?,
    onLoadGame: suspend (Int) -> Unit,
) {
    val payload = runCatching {
        msg.message?.let { BettyJson.decodeFromJsonElement<EvaluateGamePayload>(it) }
    }.getOrNull()

    val gameId = payload?.gameId ?: 0
    val game = if (gameId != 0) gameById(gameId) else null

    LaunchedEffect(gameId) {
        if (gameId != 0 && gameById(gameId) == null) {
            onLoadGame(gameId)
        }
    }

    if (game != null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val home = teamById(game.homeTeamId)
            val away = teamById(game.awayTeamId)
            Text(
                text = "Game evaluated",
                style = BettyTheme.type.body,
                color = BettyTheme.colors.textPrimary,
            )
            Spacer(Modifier.width(Space.xxs))
            if (home != null) {
                TeamLogo(url = home.imageUrl, name = home.name, size = 19.dp)
            }
            Text(
                text = " ${game.homeTeamScore} - ${game.awayTeamScore} ",
                style = BettyTheme.type.subhead,
                color = BettyTheme.colors.textPrimary,
            )
            if (away != null) {
                TeamLogo(url = away.imageUrl, name = away.name, size = 19.dp)
            }
        }
    }
}

/**
 * `group_joined` (components.md §7.5). "{who|Someone} just joined {group.name}".
 */
@Composable
private fun FeedGroupJoinedItem(msg: ActivityMessage) {
    val payload = runCatching {
        msg.message?.let { BettyJson.decodeFromJsonElement<GroupJoinedPayload>(it) }
    }.getOrNull()

    val who = payload?.who?.takeIf { it.isNotEmpty() } ?: "Someone"
    val groupName = payload?.group?.name ?: ""
    val colors = BettyTheme.colors

    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(who) }
            append(" just joined ")
            withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(groupName) }
        },
        style = BettyTheme.type.body,
        color = colors.textPrimary,
    )
}

/**
 * `group_visibility_changed` (components.md §7.6). Group name resolved from the group store
 * — only when group_id is an integer (string IDs must NOT match per spec).
 */
@Composable
private fun FeedVisibilityItem(
    msg: ActivityMessage,
    groupNameById: (Int) -> String?,
) {
    val payload = runCatching {
        msg.message?.let { BettyJson.decodeFromJsonElement<VisibilityChangedPayload>(it) }
    }.getOrNull()

    val groupId = payload?.groupId
    // Per spec: group_id must be a number (not a string "7"). The payload model decodes
    // group_id as Int, so decoding success guarantees it was a JSON number.
    val resolvedName = if (groupId != null) {
        groupNameById(groupId)?.takeIf { it.isNotEmpty() } ?: "A group"
    } else {
        "A group"
    }
    val visibility = if (payload?.publicAt != null) "public" else "private"
    val colors = BettyTheme.colors

    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(resolvedName) }
            append(" is now ")
            withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(visibility) }
        },
        style = BettyTheme.type.body,
        color = colors.textPrimary,
    )
}

/**
 * `user_exact_score` (components.md §7.7). "You and N other(s)…" when signed-in user is
 * among the ids; otherwise "N players had the exact score!".
 */
@Composable
private fun FeedExactScoreItem(msg: ActivityMessage, currentUserId: String?) {
    val payload = runCatching {
        msg.message?.let { BettyJson.decodeFromJsonElement<ExactScorePayload>(it) }
    }.getOrNull()

    val userIds = payload?.userIds ?: emptyList()
    val count = userIds.size

    val text = if (currentUserId != null && userIds.contains(currentUserId)) {
        "You and ${count - 1} other(s) had the exact score"
    } else {
        "$count players had the exact score!"
    }

    Text(
        text = text,
        style = BettyTheme.type.body,
        color = BettyTheme.colors.textPrimary,
    )
}

/**
 * `user_register` (components.md §7.1 table). "{name} just joined Betty".
 */
@Composable
private fun FeedWelcomeItem(msg: ActivityMessage) {
    val name = runCatching {
        msg.message?.jsonObject?.get("name")?.jsonPrimitive?.content ?: ""
    }.getOrDefault("")
    val colors = BettyTheme.colors

    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight(800))) { append(name) }
            append(" just joined Betty")
        },
        style = BettyTheme.type.body,
        color = colors.textPrimary,
    )
}
