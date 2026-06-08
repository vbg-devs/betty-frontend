package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import social.betty.core.logic.RankedMember
import social.betty.core.logic.Ranking
import social.betty.core.model.GroupMember
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.ScoreRow
import social.betty.designsystem.components.YouBadge

/** Web `TopThree.vue`: top 3 by score, medium avatars, tap selects the member. */
@Composable
fun GroupTopThree(members: List<GroupMember>, onSelect: (GroupMember) -> Unit) {
    val topThree = members.sortedByDescending { it.score }.take(3)
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Space.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        topThree.forEach { member ->
            Box(modifier = Modifier.clickable { onSelect(member) }) {
                Avatar(url = member.imageUrl, name = member.displayName(), size = AvatarSize.medium)
            }
        }
    }
}

/**
 * Web `Leaderboard.vue` (group mode): dense tie-ranked rows, zero-padded places, top-3
 * place accents keyed on place, "YOU" highlight, tap opens the member's bet history.
 */
@Composable
fun GroupLeaderboardList(
    members: List<GroupMember>,
    myId: String?,
    onSelect: (GroupMember) -> Unit,
    modifier: Modifier = Modifier,
) {
    val ranked = Ranking.rank(members)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .testTag("group-leaderboard-list"),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        ranked.forEach { entry ->
            LeaderboardRow(
                entry = entry,
                isYou = myId != null && entry.userId == myId,
                onSelect = { onSelect(entry.member) },
            )
        }
    }
}

@Composable
private fun LeaderboardRow(entry: RankedMember, isYou: Boolean, onSelect: () -> Unit) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val placeColor = when (entry.place) {
        1 -> Palette.orange
        2 -> Palette.yellow
        else -> colors.textSecondary
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .background(if (isYou) Palette.orangeTint12 else colors.surface)
            .clickable { onSelect() }
            .testTag("group-leaderboard-row"),
    ) {
        if (isYou) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .fillMaxHeight()
                    .background(Palette.orange),
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 14.dp, horizontal = Space.l),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            Text(
                text = Ranking.placementLabel(entry.place),
                style = type.title3,
                color = placeColor,
                modifier = Modifier.width(40.dp),
            )
            Avatar(url = entry.member.imageUrl, name = entry.member.displayName(), size = AvatarSize.small)
            Text(
                text = entry.member.displayName(),
                style = type.body,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (isYou) {
                Spacer(Modifier.width(Space.xs))
                YouBadge()
            }
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically) {
                ScoreRow(
                    text = entry.member.score.toString(),
                    color = if (entry.place == 1) colors.accentPositive else colors.textPrimary,
                )
                Spacer(Modifier.width(4.dp))
                Text(text = "P", style = type.kicker, color = colors.textSecondary)
            }
        }
    }
}

/** Final podium: places 1–3, ties grouped per slot, visual order 2-1-3, slot 1 on orange. */
@Composable
fun GroupPodium(members: List<GroupMember>, onSelect: (GroupMember) -> Unit) {
    val ranked = Ranking.rank(members)
    val podium = Ranking.podium(ranked) // Map<place, List<member>>
    val orderedPlaces = podium.keys.sortedBy { visualOrder(it) }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Space.s),
        verticalAlignment = Alignment.Bottom,
    ) {
        orderedPlaces.forEach { place ->
            PodiumSlot(place = place, slotMembers = podium.getValue(place), onSelect = onSelect, modifier = Modifier.weight(1f))
        }
    }
}

private fun visualOrder(place: Int): Int = when (place) {
    1 -> 2
    2 -> 1
    else -> 3
}

@Composable
private fun PodiumSlot(
    place: Int,
    slotMembers: List<GroupMember>,
    onSelect: (GroupMember) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val isFirst = place == 1
    val accent = when (place) {
        1 -> Color.White.copy(alpha = 0.85f)
        2 -> Palette.yellow
        else -> colors.textSecondary
    }
    Column(
        modifier = modifier
            .clip(Radius.sharp)
            .background(if (isFirst) Palette.orange else colors.overlay04)
            .padding(
                top = if (isFirst) Space.xl else 20.dp,
                bottom = if (isFirst) Space.l else 18.dp,
                start = 14.dp,
                end = 14.dp,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Text(text = "#$place", style = type.kicker, color = accent)
        slotMembers.forEach { member ->
            Column(
                modifier = Modifier.clickable { onSelect(member) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Avatar(
                    url = member.imageUrl,
                    name = member.displayName(),
                    size = if (isFirst && slotMembers.size == 1) AvatarSize.large else AvatarSize.medium,
                )
                Text(
                    text = member.displayName(),
                    style = type.headline,
                    color = if (isFirst) Color.White else colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "${member.score} PTS",
                    style = type.kicker,
                    color = if (isFirst) Color.White.copy(alpha = 0.85f) else colors.textSecondary,
                )
            }
        }
    }
}
