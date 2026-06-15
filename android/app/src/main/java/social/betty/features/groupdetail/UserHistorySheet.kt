package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import social.betty.core.model.Bet
import social.betty.core.model.Team
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.HiddenScore
import social.betty.designsystem.components.TeamLogo
import social.betty.navigation.LocalAppContainer
import java.time.Instant

/**
 * Web `UserHistory`: one row per game — the member's bet if placed, else a "NO BET"
 * skipped row for games that have already started. Sorted by kickoff, scores hidden
 * pre-kickoff unless sneak peek, header counts only actual bets ("<N> BETS · <Σ> PTS").
 */
@Composable
fun UserHistorySheet(groupId: Int, userId: String, onDismiss: () -> Unit) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val now = remember { Instant.now() }

    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val group = groups.firstOrNull { it.id == groupId }
    val member = group?.members?.firstOrNull { it.userId == userId }
    val peek = group?.allowSneakPeek ?: false
    val myId = container.userStore.id

    val tournamentDetails by container.tournamentStore.details.collectAsStateWithLifecycle()
    val games = group?.let { tournamentDetails[it.tournamentId]?.games } ?: emptyList()

    val teams by container.teamStore.teams.collectAsStateWithLifecycle()
    fun teamBy(id: Int): Team? = teams.firstOrNull { it.id == id }

    var bets by remember { mutableStateOf<List<Bet>>(emptyList()) }
    val entries = remember(bets, userId, games, now) {
        GroupUserHistoryLogic.entries(bets, userId, games, now)
    }

    LaunchedEffect(groupId) {
        group?.let { runCatching { container.tournamentStore.loadDetails(it.tournamentId) } }
        if (teams.isEmpty()) runCatching { container.teamStore.load() }
        runCatching { container.api.getBetsByGroup(groupId) }.onSuccess { bets = it }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .testTag("user-history-sheet"),
    ) {
        // Header.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = Space.l, start = Space.xl, end = Space.xl, bottom = Space.l),
            horizontalArrangement = Arrangement.spacedBy(Space.m),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (member != null) {
                Avatar(url = member.imageUrl, name = member.displayName(), size = AvatarSize.medium)
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
                Text("★ BET HISTORY", style = type.kicker, color = Palette.orange)
                Text(
                    text = (member?.displayName() ?: "").uppercase(),
                    style = type.title2,
                    color = colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
                    Text(
                        text = "${GroupUserHistoryLogic.betsCount(entries)} BETS",
                        style = type.kicker,
                        color = colors.textSecondary,
                    )
                    Text("·", color = colors.textMuted)
                    Text(
                        text = "${GroupUserHistoryLogic.totalPoints(entries)} PTS",
                        style = type.kicker,
                        color = colors.accentPositive,
                    )
                }
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 480.dp)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 14.dp)
                .padding(bottom = Space.l),
        ) {
            if (entries.isEmpty()) {
                Text(
                    text = "★ NO BETS YET",
                    style = type.kicker,
                    color = colors.textMuted,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Space.xl),
                    textAlign = TextAlign.Center,
                )
            }
            entries.forEachIndexed { index, entry ->
                UserHistoryBetRow(
                    entry = entry,
                    peek = peek,
                    isMine = entry.bet?.let { myId == it.userId } ?: false,
                    exactResultPoints = group?.exactResultPoints,
                    homeTeam = teamBy(entry.game.homeTeamId),
                    awayTeam = teamBy(entry.game.awayTeamId),
                    now = now,
                )
                if (index != entries.lastIndex) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp)
                            .height(1.dp)
                            .background(colors.overlay06),
                    )
                }
            }
        }
    }
}

@Composable
private fun UserHistoryBetRow(
    entry: UserHistoryEntry,
    peek: Boolean,
    isMine: Boolean,
    exactResultPoints: Int?,
    homeTeam: Team?,
    awayTeam: Team?,
    now: Instant,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val bet = entry.bet
    val showScore = bet != null && GroupBetRowLogic.showScore(bet, entry.game.startDate, peek, now)
    val result = bet?.let { GroupBetRowLogic.result(it, showScore, exactResultPoints) }
        ?: GroupBetRowLogic.Result.PENDING

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(if (bet == null) 0.55f else 1f)
            .padding(vertical = 14.dp, horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            TeamLogo(url = homeTeam?.imageUrl, name = homeTeam?.name, size = 28.dp)
            Text("–", style = type.bodyRegular, color = colors.textSecondary)
            TeamLogo(url = awayTeam?.imageUrl, name = awayTeam?.name, size = 28.dp)
        }

        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
            if (bet == null) {
                Text("NO BET", style = type.kicker, color = colors.textSecondary)
            } else if (showScore || isMine) {
                Text(
                    text = "${bet.homeTeamScore} – ${bet.awayTeamScore}",
                    style = type.score.copy(fontSize = 18.sp),
                    color = colors.textPrimary,
                )
            } else {
                HiddenScore()
            }
        }

        Box(modifier = Modifier.width(64.dp), contentAlignment = Alignment.CenterEnd) {
            // Points stay pending until visible AND processed (isMine does not unlock points).
            if (bet == null) {
                Text("—", style = type.subhead, color = colors.textSecondary)
            } else if (showScore && bet.isProcessed) {
                val points = bet.userPoints ?: 0
                val chipColor = when (result) {
                    GroupBetRowLogic.Result.EXACT -> colors.accentPositive
                    GroupBetRowLogic.Result.WIN -> Palette.yellow
                    GroupBetRowLogic.Result.MISS -> Palette.orange
                    GroupBetRowLogic.Result.PENDING -> colors.textSecondary
                }
                Text(
                    text = if (points > 0) "+${points}P" else "0P",
                    style = type.kicker,
                    color = chipColor,
                    modifier = Modifier
                        .clip(Radius.sharp)
                        .background(chipColor.copy(alpha = 0.15f))
                        .padding(vertical = 4.dp, horizontal = 8.dp),
                )
            } else {
                Text("·", style = type.subhead, color = colors.textSecondary)
            }
        }
    }
}
