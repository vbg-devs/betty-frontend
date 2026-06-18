package social.betty.features.groupdetail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.core.logic.DayGroup
import social.betty.core.logic.GameSchedule
import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Team
import social.betty.core.model.Tournament
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import java.time.Instant

/**
 * Web `Pools.vue`: the full schedule — games flattened across pools, sorted by kickoff,
 * grouped by calendar day with pool-name headers; the next-upcoming day gets an orange dot.
 */
@Composable
fun GroupSchedule(
    detail: Tournament?,
    bets: List<Bet>,
    userId: String?,
    teamBy: (Int) -> Team?,
    onGameTap: (Game) -> Unit,
    now: Instant = Instant.now(),
    modifier: Modifier = Modifier,
) {
    val dayGroups: List<DayGroup> = if (detail == null) emptyList() else GameSchedule.group(detail, bets, userId, now)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("group-games-list"),
        verticalArrangement = Arrangement.spacedBy(Space.xl),
    ) {
        dayGroups.forEach { day ->
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(
                    text = ((if (day.isNextUpcoming) "● " else "") +
                        dayGroupHeaderText(day.poolNames, day.title)).uppercase(),
                    style = BettyTheme.type.kicker,
                    color = Palette.orange,
                )
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    day.games.forEach { annotation ->
                        val game = annotation.game
                        GroupGameCard(
                            game = game,
                            homeTeam = teamBy(game.homeTeamId),
                            awayTeam = teamBy(game.awayTeamId),
                            betted = annotation.hasBet,
                            placedHome = annotation.myHome ?: 0,
                            placedAway = annotation.myAway ?: 0,
                            awardedPoints = GroupGameCardLogic.awardedPoints(game, bets, userId),
                            awardedBoosted = GroupGameCardLogic.awardedBoosted(game, bets, userId),
                            placedBoosted = annotation.myBoosted,
                            betCount = annotation.betCount,
                            onTap = { onGameTap(game) },
                            now = now,
                        )
                    }
                }
            }
        }
    }
}
