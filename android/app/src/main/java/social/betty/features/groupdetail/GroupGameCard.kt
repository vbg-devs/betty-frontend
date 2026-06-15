package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import social.betty.core.logic.GameSchedule
import social.betty.core.model.Game
import social.betty.core.model.Team
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.LiveBadge
import social.betty.designsystem.components.TeamLogo
import java.time.Instant

/**
 * Web `Game.vue` (default layout): info row (LIVE badge or kickoff label) above two teams
 * flanking the big score, optional placed-bet chip with awarded points underneath it,
 * 45% dim when finished, optional bet-count chip overlay.
 */
@Composable
fun GroupGameCard(
    game: Game,
    homeTeam: Team?,
    awayTeam: Team?,
    betted: Boolean,
    placedHome: Int,
    placedAway: Int,
    awardedPoints: Int?,
    /** null hides the chip (web `showBets == false`). */
    betCount: Int?,
    onTap: () -> Unit,
    now: Instant = Instant.now(),
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface)
            .clickable { onTap() }
            .alpha(if (game.isFinished) 0.45f else 1f)
            .testTag("group-game-card"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp, start = 16.dp, end = 16.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            // Info row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (GameSchedule.isLive(game, now)) {
                    LiveBadge()
                } else {
                    Text(
                        text = GameSchedule.kickoffLabel(game.startDate, now).uppercase(),
                        style = type.kicker,
                        color = colors.textMuted,
                    )
                }
                Spacer(Modifier.weight(1f))
            }

            // Teams + score
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Space.xs),
                verticalAlignment = Alignment.Top,
            ) {
                teamColumn(homeTeam, Modifier.weight(1f))
                Column(
                    modifier = Modifier.padding(top = Space.m),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = game.homeTeamScore.toString(),
                            style = type.score,
                            color = colors.textPrimary,
                        )
                        Text(
                            text = " - ",
                            style = type.bodyRegular.copy(fontSize = 18.sp),
                            color = colors.textSecondary,
                        )
                        Text(
                            text = game.awayTeamScore.toString(),
                            style = type.score,
                            color = colors.textPrimary,
                        )
                    }
                    if (betted) {
                        Text(
                            text = "$placedHome - $placedAway",
                            style = type.kicker,
                            color = Palette.orange,
                            modifier = Modifier
                                .clip(Radius.sharp)
                                .background(Palette.orangeTint15)
                                .padding(vertical = 3.dp, horizontal = 8.dp),
                        )
                    }
                    if (awardedPoints != null) {
                        Text(
                            text = "${awardedPoints}P",
                            style = type.kicker,
                            color = if (awardedPoints > 0) colors.accentPositive else colors.textSecondary,
                        )
                    }
                }
                teamColumn(awayTeam, Modifier.weight(1f))
            }
        }

        // Bet-count chip (top-trailing).
        if (betCount != null) {
            Text(
                text = "👥 $betCount",
                style = type.kicker,
                color = colors.textSecondary,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(10.dp)
                    .clip(Radius.sharp)
                    .background(colors.overlay08)
                    .padding(vertical = 4.dp, horizontal = 8.dp)
                    .testTag("group-game-bet-count"),
            )
        }
    }
}

@Composable
private fun teamColumn(team: Team?, modifier: Modifier) {
    val colors = BettyTheme.colors
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TeamLogo(url = team?.imageUrl, name = team?.name, size = 56.dp)
        Text(
            text = (team?.name ?: "").uppercase(),
            style = BettyTheme.type.caption.copy(fontWeight = FontWeight(800)),
            color = colors.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.wrapContentWidth(),
        )
    }
}
