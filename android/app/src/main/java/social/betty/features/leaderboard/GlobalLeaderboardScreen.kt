package social.betty.features.leaderboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import social.betty.core.logic.Dashboard
import social.betty.core.logic.RankedMember
import social.betty.core.logic.Ranking
import social.betty.core.model.GroupMember
import social.betty.core.model.Tournament
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.ScoreRow
import social.betty.designsystem.components.SurfaceCard
import social.betty.designsystem.components.YouBadge
import social.betty.navigation.LocalAppContainer

@Composable
fun GlobalLeaderboardScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()

    val tournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    val currentUserId = container.userStore.id

    // Determine default tournament from running + all list.
    val defaultTournament = remember(tournaments) {
        Dashboard.defaultLeaderboardTournament(
            running = container.tournamentStore.running(),
            all = tournaments,
        )
    }

    var selectedTournamentId by remember(defaultTournament) {
        mutableStateOf(defaultTournament?.id)
    }

    var members by remember { mutableStateOf<List<GroupMember>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var loadFailed by remember { mutableStateOf(false) }
    var hasSettled by remember { mutableStateOf(false) }
    // Generation counter prevents stale responses from a previous selection overwriting a newer one.
    var loadGeneration by remember { mutableIntStateOf(0) }

    fun reload() {
        val id = selectedTournamentId ?: return
        loadGeneration++
        val gen = loadGeneration
        isLoading = true
        loadFailed = false
        scope.launch {
            try {
                val rows = container.api.getTournamentLeaderboard(id, 100)
                if (gen == loadGeneration) {
                    members = rows
                    loadFailed = false
                }
            } catch (_: Exception) {
                if (gen == loadGeneration) {
                    members = emptyList()
                    loadFailed = true
                }
            } finally {
                if (gen == loadGeneration) {
                    isLoading = false
                    hasSettled = true
                }
            }
        }
    }

    // Reload whenever the selected tournament changes.
    LaunchedEffect(selectedTournamentId) {
        if (selectedTournamentId != null) reload()
    }

    val ranked: List<RankedMember> = remember(members) {
        Ranking.rankByNormalized(members)
    }

    BettyScaffold(
        modifier = Modifier.testTag("leaderboard-screen"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m),
            verticalArrangement = Arrangement.spacedBy(Space.grid),
        ) {
            HeroCard(
                tournaments = tournaments,
                selectedTournamentId = selectedTournamentId,
                memberCount = members.size,
                hasSettled = hasSettled,
                onTournamentSelected = { id ->
                    selectedTournamentId = id
                },
            )

            StandingsSection(
                ranked = ranked,
                isLoading = isLoading,
                loadFailed = loadFailed,
                hasSettled = hasSettled,
                currentUserId = currentUserId,
                onRetry = { reload() },
            )

            Spacer(Modifier.height(Space.xxl))
        }
    }
}

// ---- Hero card ---------------------------------------------------------------

@Composable
private fun HeroCard(
    tournaments: List<Tournament>,
    selectedTournamentId: Int?,
    memberCount: Int,
    hasSettled: Boolean,
    onTournamentSelected: (Int) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    SurfaceCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            // Normalized scoring notice
            InsetPanel(accent = Palette.yellow) {
                Text(
                    text = "Normalized score: 1p correct winner, 3p exact score — may differ from your groups.",
                    style = type.bodyRegular,
                    color = colors.textSecondary,
                )
            }

            KickerText(
                text = "★ GLOBAL LEADERBOARD",
                color = Palette.orange,
            )

            // Tournament picker
            Column(
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                KickerText(
                    text = "★ SWITCH TOURNAMENT",
                    color = colors.textSecondary,
                )

                TournamentPicker(
                    tournaments = tournaments,
                    selectedId = selectedTournamentId,
                    onSelect = onTournamentSelected,
                )
            }

            if (hasSettled) {
                PlayerCountRow(count = memberCount)
            }
        }
    }
}

// ---- Tournament picker -------------------------------------------------------

@Composable
private fun TournamentPicker(
    tournaments: List<Tournament>,
    selectedId: Int?,
    onSelect: (Int) -> Unit,
) {
    val type = BettyTheme.type
    val colors = BettyTheme.colors

    val selected = tournaments.firstOrNull { it.id == selectedId }
    var expanded by remember { mutableStateOf(false) }

    Box(modifier = Modifier.testTag("leaderboard-picker")) {
        BettyButton(
            text = selected?.let { pickerLabel(it) } ?: "Select tournament",
            onClick = { expanded = true },
            variant = BettyButtonVariant.OUTLINE,
        )

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            tournaments.forEach { tournament ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = pickerLabel(tournament),
                            style = type.body,
                            color = colors.textPrimary,
                        )
                    },
                    onClick = {
                        onSelect(tournament.id)
                        expanded = false
                    },
                )
            }
        }
    }
}

/**
 * Display label for a tournament in the picker.
 * Tournaments with `endDate` in the past are suffixed "· ENDED".
 */
private fun pickerLabel(tournament: Tournament): String {
    val isEnded = tournament.endDate != null &&
        tournament.endDate.isBefore(java.time.Instant.now())
    return if (isEnded) "${tournament.name} · ENDED" else tournament.name
}

// ---- Player count ------------------------------------------------------------

@Composable
private fun PlayerCountRow(count: Int) {
    val type = BettyTheme.type
    val colors = BettyTheme.colors

    Row(
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Text(
            text = count.toString(),
            style = type.displayL,
            color = colors.textPrimary,
        )
        KickerText(
            text = "PLAYERS · CHASING",
            color = colors.textSecondary,
        )
    }
}

// ---- Standings section -------------------------------------------------------

@Composable
private fun StandingsSection(
    ranked: List<RankedMember>,
    isLoading: Boolean,
    loadFailed: Boolean,
    hasSettled: Boolean,
    currentUserId: String?,
    onRetry: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        KickerText(text = "● STANDINGS", color = Palette.orange)
        Text(
            text = "WHO'S BETTING IT RIGHT.",
            style = type.title1,
            color = colors.textPrimary,
        )

        when {
            isLoading -> {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Space.xxl),
                ) {
                    CircularProgressIndicator(color = Palette.orange)
                }
            }

            loadFailed -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Space.s),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Space.l),
                ) {
                    Text(
                        text = "Could not load the leaderboard.",
                        style = type.bodyRegular,
                        color = colors.textSecondary,
                    )
                    BettyButton(
                        text = "RETRY",
                        onClick = onRetry,
                        variant = BettyButtonVariant.OUTLINE,
                    )
                }
            }

            ranked.isEmpty() && hasSettled -> {
                Text(
                    text = "No players on the board yet.",
                    style = type.bodyRegular,
                    color = colors.textSecondary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Space.l)
                        .testTag("leaderboard-empty"),
                )
            }

            else -> {
                Column(
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.clip(Radius.sharp),
                ) {
                    ranked.forEach { rankedMember ->
                        LeaderboardRow(
                            ranked = rankedMember,
                            currentUserId = currentUserId,
                        )
                    }
                }
            }
        }
    }
}

// ---- Single leaderboard row --------------------------------------------------

@Composable
private fun LeaderboardRow(
    ranked: RankedMember,
    currentUserId: String?,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val isYou = currentUserId != null && ranked.userId == currentUserId
    val placeColor = when (ranked.place) {
        1 -> Palette.orange
        2 -> Palette.yellow
        else -> colors.textSecondary
    }
    val scoreColor = when {
        ranked.place == 1 -> colors.accentPositive
        else -> colors.textPrimary
    }
    val normalizedScore = ranked.member.normalizedScore ?: 0.0
    val scoreText = if (normalizedScore == normalizedScore.toLong().toDouble()) {
        normalizedScore.toLong().toString()
    } else {
        normalizedScore.toString()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (isYou) Palette.orangeTint12 else colors.surface)
            .testTag("leaderboard-row"),
    ) {
        // Orange left border for the current user's row
        if (isYou) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(56.dp)
                    .background(Palette.orange)
                    .align(Alignment.CenterStart),
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.s),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 14.dp, horizontal = Space.m),
        ) {
            // Place number — zero-padded to 2 digits
            Text(
                text = "%02d".format(ranked.place),
                style = type.title3,
                color = placeColor,
            )

            // Avatar — global mode uses name (nickname is null on this wire payload)
            Avatar(
                url = ranked.member.imageUrl,
                name = ranked.member.name,
                size = AvatarSize.default,
            )

            // Name (global mode: always name, not nickname)
            Text(
                text = ranked.member.name ?: "",
                style = type.body,
                color = colors.textPrimary,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )

            // Country flag emoji (optional)
            // The GroupMember model doesn't carry country directly in this payload;
            // the web/iOS do not show flags on the global leaderboard either — omitted.

            // YOU badge
            if (isYou) {
                YouBadge(modifier = Modifier.testTag("leaderboard-you"))
            }

            // Normalized score
            ScoreRow(
                text = scoreText,
                color = scoreColor,
            )

            Text(
                text = "P",
                style = type.kicker,
                color = colors.textSecondary,
            )
        }
    }
}
