package social.betty.features.groupdetail

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.SecondaryTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import social.betty.core.logic.RankedMember
import social.betty.core.logic.Ranking
import social.betty.core.model.Bet
import social.betty.core.model.Group
import social.betty.core.model.GroupMessage
import social.betty.core.model.Team
import social.betty.core.model.Tournament
import social.betty.core.model.WebSocketEventType
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.ThemeColors
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyProgressBar
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.EmptyState
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalNavigator
import social.betty.navigation.Sheet
import java.time.Instant

/**
 * Web `/dashboard/groups/[id]` — the core screen: hero with rank/champion stats + author
 * cover upload, Group / Games / Leaderboard tabs, the NeedAction urgent-games strip,
 * dense-ranked standings, day-grouped schedule, bet placement, nickname editor, member
 * history drilldowns, 10 s bet + message polling and WS-driven refresh.
 */
@Composable
fun GroupDetailScreen(groupId: Int) {
    val container = LocalAppContainer.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()
    val colors = BettyTheme.colors
    val now = remember { Instant.now() }

    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val group = groups.firstOrNull { it.id == groupId }
    val myId = container.userStore.id

    val tournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    val details by container.tournamentStore.details.collectAsStateWithLifecycle()
    val teams by container.teamStore.teams.collectAsStateWithLifecycle()

    // Screen-local poll caches.
    var bets by remember(groupId) { mutableStateOf<List<Bet>>(emptyList()) }
    var messages by remember(groupId) { mutableStateOf<List<GroupMessage>>(emptyList()) }
    var warnedBetsFailure by remember { mutableStateOf(false) }

    // Poll bets every 10 s while visible.
    LaunchedEffect(groupId, group?.tournamentId) {
        val g = group ?: return@LaunchedEffect
        if (details[g.tournamentId] == null) {
            runCatching { container.tournamentStore.loadDetails(g.tournamentId) }
        }
        if (teams.isEmpty()) runCatching { container.teamStore.load() }
        while (isActive) {
            runCatching { container.api.getBetsByGroup(groupId) }
                .onSuccess { bets = it }
                .onFailure {
                    if (!warnedBetsFailure) {
                        warnedBetsFailure = true
                        container.notify.error("Could not load bets. Please refresh.")
                    }
                }
            delay(10_000)
        }
    }

    // Poll messages every 10 s while visible.
    LaunchedEffect(groupId) {
        if (container.groupStore.byId(groupId) == null) {
            runCatching { container.groupStore.load() }
        }
        while (isActive) {
            runCatching { container.api.getMessages(groupId) }.onSuccess { messages = it }
            delay(10_000)
        }
    }

    // evaluate_game WS → force-reload tournament details + bets.
    LaunchedEffect(groupId, group?.tournamentId) {
        val g = group ?: return@LaunchedEffect
        container.socket.events.collect { envelope ->
            if (envelope.type == WebSocketEventType.EVALUATE_GAME) {
                runCatching { container.tournamentStore.loadDetails(g.tournamentId, force = true) }
                runCatching { container.api.getBetsByGroup(groupId) }.onSuccess { bets = it }
            }
        }
    }

    BettyScaffold {
        if (group == null) {
            // Web renders nothing if not found; here: placeholder + pop.
            LaunchedEffect(groupId) {
                delay(400)
                if (container.groupStore.byId(groupId) == null) nav.pop()
            }
            EmptyState(
                title = "Group not found",
                message = "This group isn't in your list.",
                modifier = Modifier
                    .fillMaxSize()
                    .testTag("group-detail-screen"),
            )
            return@BettyScaffold
        }

        val detail = details[group.tournamentId]
        val tournament = tournaments.firstOrNull { it.id == group.tournamentId }
        val tournamentEnded = tournamentEnded(tournament, now)
        val allGames = detail?.games ?: emptyList()
        val completeGames = allGames.filter { it.isFinished }
        val ranked = Ranking.rank(group.members)
        val isAuthor = group.isAuthor(myId)

        var selectedTab by remember(groupId) { mutableStateOf(0) } // 0 group, 1 games, 2 leaderboard
        // After end, the Games tab is hidden — re-map a stale selection back to Group.
        val tabLabels = if (tournamentEnded) listOf("Group", "Leaderboard") else listOf("Group", "Games", "Leaderboard")
        val effectiveIndex = selectedTab.coerceIn(0, tabLabels.lastIndex)
        // Logical tab regardless of label list: 0=group,1=games,2=leaderboard.
        val logicalTab = when {
            tournamentEnded -> if (effectiveIndex == 0) 0 else 2
            else -> effectiveIndex
        }

        fun teamBy(id: Int): Team? = teams.firstOrNull { it.id == id }
        fun openBetSheet(gameId: Int) = nav.present(Sheet.Bet(gameId, groupId))
        fun openHistory(userId: String) = nav.present(Sheet.UserHistory(groupId, userId))

        val listState = rememberLazyListState()

        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .testTag("group-detail-screen"),
            contentPadding = PaddingValues(Space.m),
            verticalArrangement = Arrangement.spacedBy(Space.l),
        ) {
            item(key = "hero") {
                Hero(
                    group = group,
                    tournament = tournament,
                    tournamentEnded = tournamentEnded,
                    allGames = allGames.size,
                    completeGames = completeGames.size,
                    ranked = ranked,
                    myId = myId,
                    isAuthor = isAuthor,
                    onUploadCover = { contentType, bytes ->
                        scope.launch {
                            try {
                                container.groupStore.uploadHeaderImage(groupId, contentType, bytes)
                                container.notify.success("Cover updated.")
                            } catch (e: ApiError.Status) {
                                container.notify.error(coverErrorMessage(e.code))
                            } catch (e: ApiError) {
                                container.notify.error("Could not update cover. Please try again.")
                            }
                        }
                    },
                )
            }

            item(key = "tabs") {
                val tabIndices = if (tournamentEnded) listOf(0, 2) else listOf(0, 1, 2)
                TabBar(
                    labels = tabLabels,
                    selectedIndex = effectiveIndex,
                    onSelect = { selectedTab = it },
                    logicalForLabel = { tabIndices[it] },
                )
            }

            when (logicalTab) {
                0 -> groupTab(
                    group = group,
                    tournamentEnded = tournamentEnded,
                    ranked = ranked,
                    allGames = allGames,
                    bets = bets,
                    messages = messages,
                    myId = myId,
                    isAuthor = isAuthor,
                    teamBy = ::teamBy,
                    now = now,
                    onSeeLeaderboard = { selectedTab = tabLabels.lastIndex },
                    onOpenBet = ::openBetSheet,
                    onOpenHistory = ::openHistory,
                    onOpenSettings = { nav.present(Sheet.GroupSettings(groupId)) },
                )
                1 -> item(key = "games") {
                    GroupSchedule(
                        detail = detail,
                        bets = bets,
                        userId = myId,
                        teamBy = ::teamBy,
                        onGameTap = { openBetSheet(it.id) },
                        now = now,
                    )
                }
                2 -> item(key = "leaderboard") {
                    GroupLeaderboardList(
                        members = group.members,
                        myId = myId,
                        onSelect = { openHistory(it.userId) },
                    )
                }
            }
        }

        // Auto-scroll to the next-upcoming day when the Games tab opens.
        LaunchedEffect(logicalTab, detail) {
            if (logicalTab != 1 || detail == null) return@LaunchedEffect
            delay(300)
            listState.animateScrollToItem(index = 2) // hero, tabs, then schedule item
        }
    }
}

private fun tournamentEnded(tournament: Tournament?, now: Instant): Boolean {
    if (tournament == null) return true
    val end = tournament.endDate ?: return false
    return end.isBefore(now)
}

private fun coverErrorMessage(status: Int): String = when (status) {
    401, 403 -> "Only the group author can change the cover."
    413 -> "Image is too large (max 1 MB)."
    415 -> "That image type isn't supported."
    503 -> "Uploads are unavailable right now. Please try again later."
    else -> "Could not update cover. Please try again."
}

@Composable
private fun Hero(
    group: Group,
    tournament: Tournament?,
    tournamentEnded: Boolean,
    allGames: Int,
    completeGames: Int,
    ranked: List<RankedMember>,
    myId: String?,
    isAuthor: Boolean,
    onUploadCover: (String, ByteArray) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val context = LocalContext.current
    val hasCover = !group.headerImageUrl.isNullOrEmpty()
    var isUploading by remember { mutableStateOf(false) }

    val textPrimary = if (hasCover) ThemeColors.dark.textPrimary else colors.textPrimary
    val textSecondary = if (hasCover) ThemeColors.dark.textSecondary else colors.textSecondary

    val pickMedia = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        isUploading = true
        val resolver = context.contentResolver
        val contentType = resolver.getType(uri) ?: "image/jpeg"
        val bytes = runCatching { resolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
        isUploading = false
        if (bytes != null) onUploadCover(contentType, bytes)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .testTag("group-hero"),
    ) {
        if (hasCover) {
            AsyncImage(
                model = group.headerImageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize(),
            )
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color(0xFF141938).copy(alpha = 0.55f),
                                Color(0xFF141938).copy(alpha = 0.88f),
                            ),
                        ),
                    ),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (hasCover) Color.Transparent else colors.surface)
                .padding(Space.l),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            Text(
                text = "★ YOUR GROUP" + (tournament?.let { " · ${it.name.uppercase()}" } ?: ""),
                style = type.kicker,
                color = Palette.orange,
            )
            Text(
                text = group.name.uppercase(),
                style = type.displayL,
                color = textPrimary,
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
                Text("${group.members.size} MEMBERS", style = type.kicker, color = textSecondary)
                if (allGames > 0) {
                    Text("·", color = textSecondary)
                    Text("$completeGames OF $allGames GAMES", style = type.kicker, color = textSecondary)
                }
                Text("·", color = textSecondary)
                Text(
                    text = if (tournamentEnded) "○ FINAL" else "● ACTIVE",
                    style = type.kicker,
                    color = if (tournamentEnded) textSecondary else colors.accentPositive,
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(Space.s), modifier = Modifier.fillMaxWidth()) {
                if (tournamentEnded) {
                    ChampionTile(ranked, myId, Modifier.weight(1f))
                    FinishTile(ranked, myId, group.members.size, textPrimary, textSecondary, Modifier.weight(1f))
                } else {
                    RankTile(ranked, myId, group.members.size, Modifier.weight(1f))
                    GamesPlayedTile(completeGames, allGames, textPrimary, textSecondary, Modifier.weight(1f))
                }
            }

            if (isAuthor) {
                Text(
                    text = when {
                        isUploading -> "UPLOADING…"
                        hasCover -> "CHANGE COVER →"
                        else -> "+ ADD COVER"
                    },
                    style = type.kicker,
                    color = if (hasCover) ThemeColors.dark.textPrimary else Palette.orange,
                    modifier = Modifier
                        .clickable(enabled = !isUploading) {
                            pickMedia.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }
                        .testTag("group-cover-cta"),
                )
            }
        }
    }
}

@Composable
private fun RankTile(
    ranked: List<RankedMember>,
    myId: String?,
    memberCount: Int,
    modifier: Modifier,
) {
    val type = BettyTheme.type
    StatTile(background = Palette.orange, modifier = modifier) {
        Text("YOUR RANK", style = type.kicker, color = Color.White.copy(alpha = 0.85f))
        Text(
            text = Ranking.placementLabel(Ranking.placementOf(ranked, myId)),
            style = type.displayXL,
            color = Color.White,
        )
        Text("OF %02d".format(memberCount), style = type.kicker, color = Color.White.copy(alpha = 0.85f))
    }
}

@Composable
private fun GamesPlayedTile(
    completeGames: Int,
    allGames: Int,
    textPrimary: Color,
    textSecondary: Color,
    modifier: Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val percent = GroupStandings.completionPercentage(completeGames, allGames)
    StatTile(background = colors.overlay06, modifier = modifier) {
        Text("GAMES PLAYED", style = type.kicker, color = textSecondary)
        Row(verticalAlignment = Alignment.Bottom) {
            Text("$percent", style = type.displayXL, color = textPrimary)
            Text("%", style = type.score, color = textPrimary.copy(alpha = 0.75f))
        }
        Spacer(Modifier.height(Space.xs))
        BettyProgressBar(progress = percent.toFloat())
    }
}

@Composable
private fun ChampionTile(
    ranked: List<RankedMember>,
    myId: String?,
    modifier: Modifier,
) {
    val type = BettyTheme.type
    val champions = Ranking.champions(ranked)
    val champion = champions.firstOrNull()
    val youWon = Ranking.youWon(ranked, myId)
    StatTile(background = Palette.orange, modifier = modifier) {
        Text(if (youWon) "YOU WON" else "CHAMPION", style = type.kicker, color = Color.White.copy(alpha = 0.85f))
        if (champion != null) {
            Avatar(
                url = champion.imageUrl,
                name = champion.displayName(),
                size = AvatarSize.medium,
            )
            Text(
                text = champion.displayName(),
                style = type.title3,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text("${champion.score} PTS", style = type.kicker, color = Color.White.copy(alpha = 0.85f))
        } else {
            Text("–", style = type.displayXL, color = Color.White)
        }
    }
}

@Composable
private fun FinishTile(
    ranked: List<RankedMember>,
    myId: String?,
    memberCount: Int,
    textPrimary: Color,
    textSecondary: Color,
    modifier: Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    StatTile(background = colors.overlay06, modifier = modifier) {
        Text("YOUR FINISH", style = type.kicker, color = textSecondary)
        Text(
            text = Ranking.placementLabel(Ranking.placementOf(ranked, myId)),
            style = type.displayXL,
            color = textPrimary,
        )
        Text("OF %02d".format(memberCount), style = type.kicker, color = textSecondary)
    }
}

@Composable
private fun StatTile(background: Color, modifier: Modifier, content: @Composable () -> Unit) {
    Column(
        modifier = modifier
            .heightIn(min = 140.dp)
            .clip(Radius.sharp)
            .background(background)
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(Space.xs),
        horizontalAlignment = Alignment.Start,
    ) {
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TabBar(
    labels: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    logicalForLabel: (Int) -> Int,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    SecondaryTabRow(
        selectedTabIndex = selectedIndex,
        modifier = Modifier.fillMaxWidth(),
        containerColor = Color.Transparent,
        contentColor = Palette.orange,
        divider = { HorizontalDivider(thickness = 1.dp, color = colors.overlay08) },
    ) {
        labels.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            val tag = when (logicalForLabel(index)) {
                0 -> "group-tab-group"
                1 -> "group-tab-games"
                else -> "group-tab-leaderboard"
            }
            Tab(
                selected = selected,
                onClick = { onSelect(index) },
                selectedContentColor = colors.textPrimary,
                unselectedContentColor = colors.textMuted,
                modifier = Modifier.testTag(tag),
            ) {
                Text(
                    text = label.uppercase(),
                    style = type.caption,
                    color = if (selected) colors.textPrimary else colors.textMuted,
                    modifier = Modifier.padding(vertical = Space.s),
                )
            }
        }
    }
}
