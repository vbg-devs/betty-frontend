package social.betty.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import social.betty.core.logic.DashboardGroup
import social.betty.core.logic.DashboardItem
import social.betty.core.model.Tournament
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.EndedBadge
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.PublicBadge
import social.betty.navigation.LocalNavigator
import social.betty.navigation.Route

/**
 * Dispatches a [DashboardItem] to either a single group card or a tournament bucket card.
 */
@Composable
fun DashboardItemCard(item: DashboardItem) {
    when (item) {
        is DashboardItem.Single -> SingleGroupCard(card = item.card)
        is DashboardItem.Bucket -> BucketGroupCard(
            tournament = item.tournament,
            cards = item.cards,
        )
    }
}

/**
 * Single group card: 16:9 header image (custom header image with circular tournament icon
 * overlay, else tournament image), badges, kicker, name, member count, state, CTA.
 */
@Composable
fun SingleGroupCard(card: DashboardGroup) {
    val nav = LocalNavigator.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val group = card.group
    val tournament = card.tournament

    // Prefer custom header image; fall back to tournament image.
    val headerImage = group.headerImageUrl?.takeIf { it.isNotBlank() }
    val tournamentImage = tournament?.imageUrl?.takeIf { it.isNotBlank() }
        ?: group.tournamentImageUrl?.takeIf { it.isNotBlank() }
    val displayImage = headerImage ?: tournamentImage

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface)
            .clickable { nav.push(Route.GroupDetail(group.id)) }
            .testTag("home-group-card"),
    ) {
        // Image header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(colors.surfaceDeep),
        ) {
            if (displayImage != null) {
                AsyncImage(
                    model = displayImage,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            }

            // Bottom scrim
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color(0xFF141938).copy(alpha = 0.82f)),
                        ),
                    ),
            )

            // Overlaid tournament circle icon — only when there is a custom header image
            // and a separate tournament image to show alongside.
            if (headerImage != null && tournamentImage != null) {
                AsyncImage(
                    model = tournamentImage,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .padding(Space.xs)
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                        .align(Alignment.TopStart),
                )
            }

            // JUST ENDED badge (top-start, below tournament icon)
            if (card.recentlyEnded) {
                EndedBadge(
                    text = "JUST ENDED",
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(
                            start = if (headerImage != null && tournamentImage != null) 52.dp else Space.xs,
                            top = Space.xs,
                        ),
                )
            }

            // PUBLIC badge (top-end)
            if (group.isPublic) {
                PublicBadge(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(Space.xs),
                )
            }
        }

        // Card body
        Column(modifier = Modifier.padding(Space.l)) {
            val kickerText = tournament?.name
                ?: group.tournamentName?.takeIf { it.isNotBlank() }
                ?: "TOURNAMENT"
            KickerText(
                text = "★ $kickerText",
                color = Palette.orange,
            )
            Spacer(Modifier.height(Space.xxs))
            Text(
                text = group.name,
                style = type.title2,
                color = colors.textPrimary,
            )
            Spacer(Modifier.height(Space.xs))
            Row(verticalAlignment = Alignment.CenterVertically) {
                val memberCount = group.members.size
                Text(
                    text = "$memberCount ${if (memberCount == 1) "MEMBER" else "MEMBERS"}",
                    style = type.kicker,
                    color = colors.textMuted,
                )
                Text(
                    text = "  ·  ",
                    style = type.kicker,
                    color = colors.textMuted,
                )
                Text(
                    text = if (card.ended) "○ ENDED" else "● ACTIVE",
                    style = type.kicker,
                    color = if (card.ended) colors.textMuted else colors.accentPositive,
                )
            }
            Spacer(Modifier.height(Space.xs))
            KickerText(
                text = if (card.ended) "SEE RESULTS →" else "OPEN GROUP →",
                color = Palette.orange,
            )
        }
    }
}

/**
 * Grouped-mode bucket card: tournament header image with group count overlay,
 * then a row per group in the bucket.
 */
@Composable
fun BucketGroupCard(
    tournament: Tournament,
    cards: List<DashboardGroup>,
) {
    val nav = LocalNavigator.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val anyRecentlyEnded = cards.any { it.recentlyEnded }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface),
    ) {
        // Header image
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(colors.surfaceDeep),
        ) {
            val imgUrl = tournament.imageUrl?.takeIf { it.isNotBlank() }
            if (imgUrl != null) {
                AsyncImage(
                    model = imgUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color(0xFF141938).copy(alpha = 0.82f)),
                        ),
                    ),
            )

            if (anyRecentlyEnded) {
                EndedBadge(
                    text = "JUST ENDED",
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(Space.xs),
                )
            }

            // Bottom overlay: tournament kicker + group count pill
            Row(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .padding(horizontal = Space.m, vertical = Space.s),
                verticalAlignment = Alignment.Bottom,
            ) {
                KickerText(
                    text = "★ ${tournament.name}",
                    color = Palette.orange,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(Space.xs))
                Text(
                    text = "${cards.size} GROUPS",
                    style = type.kicker,
                    color = Color.White,
                    modifier = Modifier
                        .clip(Radius.sharp)
                        .background(Palette.pillDark)
                        .padding(vertical = 4.dp, horizontal = Space.xs),
                )
            }
        }

        // Group rows
        cards.forEachIndexed { index, card ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { nav.push(Route.GroupDetail(card.group.id)) }
                    .padding(horizontal = Space.l, vertical = Space.s)
                    .testTag("home-group-card"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = card.group.name,
                        style = type.headline,
                        color = colors.textPrimary,
                        maxLines = 1,
                    )
                    Spacer(Modifier.height(2.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val mc = card.group.members.size
                        Text(
                            text = "$mc ${if (mc == 1) "MEMBER" else "MEMBERS"}",
                            style = type.kicker,
                            color = colors.textMuted,
                        )
                        Text("  ·  ", style = type.kicker, color = colors.textMuted)
                        Text(
                            text = if (card.ended) "○ ENDED" else "● ACTIVE",
                            style = type.kicker,
                            color = if (card.ended) colors.textMuted else colors.accentPositive,
                        )
                        if (card.group.isPublic) {
                            Text("  ·  ", style = type.kicker, color = colors.textMuted)
                            Text("● PUBLIC", style = type.kicker, color = colors.accentPositive)
                        }
                    }
                }
                Text(
                    text = if (card.ended) "SEE RESULTS →" else "OPEN GROUP →",
                    style = type.kicker,
                    color = Palette.orange,
                )
            }

            if (index < cards.lastIndex) {
                HorizontalDivider(
                    thickness = 1.dp,
                    color = colors.overlay04,
                    modifier = Modifier.padding(horizontal = Space.l),
                )
            }
        }
    }
}
