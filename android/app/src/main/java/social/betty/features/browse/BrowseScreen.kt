package social.betty.features.browse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import social.betty.core.model.PublicGroupItem
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard
import social.betty.designsystem.components.TogglePills
import social.betty.core.store.NotifyCenter
import social.betty.navigation.AppNavigator
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalNavigator
import social.betty.navigation.Sheet

@Composable
fun BrowseScreen() {
    val container = LocalAppContainer.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val vm = remember { BrowseViewModel(container.api, container.groupStore) }
    val showGrouped by container.preferences.showGrouped.collectAsStateWithLifecycle()
    // Collect the full list so recomposition fires on tournament updates; running() derives
    // the filtered subset from the same in-memory value (pattern from CreateGroupSheet).
    val allTournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    val runningTournaments = remember(allTournaments) { container.tournamentStore.running() }

    // Initial load on first composition.
    LaunchedEffect(Unit) {
        try {
            vm.reload()
        } catch (_: Exception) {
            container.notify.error("Could not load groups. Please try again.")
        }
    }

    // 250 ms debounced search — only after the first page has loaded so we don't
    // double-fire on the initial empty query.
    LaunchedEffect(vm.query) {
        if (!vm.hasLoaded) return@LaunchedEffect
        delay(250)
        try {
            vm.reload()
        } catch (_: Exception) {
            container.notify.error("Could not load groups. Please try again.")
        }
    }

    // Reload immediately when the tournament filter changes.
    LaunchedEffect(vm.tournamentId) {
        if (!vm.hasLoaded) return@LaunchedEffect
        try {
            vm.reload()
        } catch (_: Exception) {
            container.notify.error("Could not load groups. Please try again.")
        }
    }

    BettyScaffold(modifier = Modifier.testTag("browse-screen")) {
        val listState = rememberLazyListState()
        val cards = BrowseGrouping.cards(vm.items.toList(), showGrouped)

        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(Space.grid),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(Space.m),
        ) {
            // Hero card with search + tournament filter.
            item(key = "hero") {
                HeroCard(
                    vm = vm,
                    tournaments = runningTournaments.map { it.id to it.name },
                    onTournamentSelected = { id ->
                        if (vm.tournamentId != id) vm.tournamentId = id
                    },
                )
            }

            // Results header: kicker + "OPEN GROUPS." / "NOTHING HERE." + toggle pills.
            item(key = "results-header") {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Bottom,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        KickerText(text = "● LIVE", color = Palette.orange)
                        Spacer(Modifier.height(Space.xxs))
                        val heading = if (vm.items.isEmpty() && vm.hasLoaded && !vm.isLoading) {
                            "NOTHING HERE."
                        } else {
                            "OPEN GROUPS."
                        }
                        Text(
                            text = heading,
                            style = type.title2,
                            color = colors.textPrimary,
                        )
                    }
                    if (vm.items.isNotEmpty()) {
                        TogglePills(
                            options = listOf("Grouped", "List"),
                            selectedIndex = if (showGrouped) 0 else 1,
                            onSelect = { index ->
                                container.preferences.setShowGrouped(index == 0)
                            },
                            modifier = Modifier.testTag("browse-filter"),
                        )
                    }
                }
            }

            // Loading state — show FETCHING card when no items yet.
            if (vm.isLoading && vm.items.isEmpty()) {
                item(key = "fetching") {
                    SurfaceCard(modifier = Modifier.testTag("browse-empty")) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = Space.xxl),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(Space.xs),
                        ) {
                            KickerText(text = "★ FETCHING", color = Palette.orange)
                            Text(
                                text = "Loading public groups…",
                                style = type.bodyRegular,
                                color = colors.textSecondary,
                            )
                        }
                    }
                }
            }

            // Empty state after load with no results.
            if (vm.items.isEmpty() && vm.hasLoaded && !vm.isLoading) {
                item(key = "empty") {
                    SurfaceCard(modifier = Modifier.testTag("browse-empty")) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = Space.l),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(Space.xs),
                        ) {
                            KickerText(text = "★ NO MATCHES", color = colors.textMuted)
                            Spacer(Modifier.height(Space.xxs))
                            Text(
                                text = "No public groups match your search.\nTry a different tournament — or start one of your own.",
                                style = type.bodyRegular,
                                color = colors.textSecondary,
                            )
                            Spacer(Modifier.height(Space.s))
                            BettyButton(
                                text = "+ START A GROUP",
                                onClick = { nav.present(Sheet.CreateGroup) },
                                variant = BettyButtonVariant.OUTLINE,
                            )
                        }
                    }
                }
            }

            // Result cards.
            items(cards, key = { it.cardKey }) { card ->
                when (card) {
                    is BrowseCard.Single -> {
                        SingleGroupCard(
                            group = card.group,
                            joiningId = vm.joiningId,
                            onOpen = { nav.openGroup(card.group.id) },
                            onJoin = {
                                scope.launch {
                                    handleJoin(vm.join(card.group), card.group.name, nav, container.notify)
                                }
                            },
                            modifier = Modifier.testTag("browse-card"),
                        )
                    }
                    is BrowseCard.TournamentBucket -> {
                        TournamentBucketCard(
                            bucket = card,
                            joiningId = vm.joiningId,
                            onOpen = { groupId -> nav.openGroup(groupId) },
                            onJoin = { item ->
                                scope.launch {
                                    handleJoin(vm.join(item), item.name, nav, container.notify)
                                }
                            },
                            modifier = Modifier.testTag("browse-card"),
                        )
                    }
                }
            }

            // LOAD MORE button (also triggered by infinite scroll via LaunchedEffect below).
            if (vm.hasMore) {
                item(key = "load-more") {
                    BettyButton(
                        text = if (vm.isLoading) "LOADING…" else "LOAD MORE ↓",
                        onClick = {
                            scope.launch {
                                try {
                                    vm.loadMore()
                                } catch (_: Exception) {
                                    container.notify.error("Could not load more groups.")
                                }
                            }
                        },
                        variant = BettyButtonVariant.OUTLINE,
                        enabled = !vm.isLoading,
                        block = true,
                        modifier = Modifier.testTag("browse-load-more"),
                    )
                }
            }
        }

        // Infinite scroll: fire loadMore when the "load-more" sentinel key becomes visible.
        LaunchedEffect(listState) {
            snapshotFlow { listState.layoutInfo.visibleItemsInfo.any { it.key == "load-more" } }
                .collect { loadMoreVisible ->
                    if (loadMoreVisible && vm.hasMore && !vm.isLoading) {
                        try {
                            vm.loadMore()
                        } catch (_: Exception) {
                            container.notify.error("Could not load more groups.")
                        }
                    }
                }
        }
    }
}

// ---------------------------------------------------------------------------
// Hero card — "FIND A GROUP. PLACE A BET." + search field + tournament filter
// ---------------------------------------------------------------------------

@Composable
private fun HeroCard(
    vm: BrowseViewModel,
    tournaments: List<Pair<Int, String>>,
    onTournamentSelected: (Int?) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    SurfaceCard {
        Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
            KickerText(text = "★ PUBLIC BOARD", color = Palette.orange)

            // Two-tone display headline.
            Column {
                Text(
                    text = "FIND A GROUP.",
                    style = type.displayL,
                    color = colors.textPrimary,
                )
                Text(
                    text = "PLACE A BET.",
                    style = type.displayL,
                    color = colors.accentPositive,
                )
            }

            Text(
                text = "Open public groups — no invite link needed.\nSearch by name, filter by tournament, jump in.",
                style = type.bodyRegular,
                color = colors.textSecondary,
            )

            // Search field.
            Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
                SearchField(
                    value = vm.query,
                    onValueChange = { vm.query = it },
                    modifier = Modifier.testTag("browse-search"),
                )

                // Tournament filter dropdown.
                TournamentFilterField(
                    selectedId = vm.tournamentId,
                    tournaments = tournaments,
                    onSelected = onTournamentSelected,
                    modifier = Modifier.testTag("browse-filter"),
                )
            }
        }
    }
}

@Composable
private fun SearchField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(verticalArrangement = Arrangement.spacedBy(Space.xxs)) {
        Text(
            text = "SEARCH",
            style = type.kicker,
            color = colors.textMuted,
        )
        Box(
            modifier = modifier
                .fillMaxWidth()
                .clip(Radius.sharp)
                .background(colors.overlay06)
                .padding(horizontal = Space.s, vertical = Space.xs),
        ) {
            if (value.isEmpty()) {
                Text(
                    text = "Sunday Roast XI…",
                    style = type.body,
                    color = colors.textMuted,
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = type.body.copy(color = colors.textPrimary),
                cursorBrush = SolidColor(colors.accentPositive),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun TournamentFilterField(
    selectedId: Int?,
    tournaments: List<Pair<Int, String>>,
    onSelected: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    var expanded by remember { mutableStateOf(false) }

    val selectedName = if (selectedId == null) {
        "All tournaments"
    } else {
        tournaments.firstOrNull { it.first == selectedId }?.second ?: "All tournaments"
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.xxs)) {
        Text(
            text = "TOURNAMENT",
            style = type.kicker,
            color = colors.textMuted,
        )
        Box(modifier = modifier) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(Radius.sharp)
                    .background(colors.overlay06)
                    .clickable { expanded = true }
                    .padding(horizontal = Space.s, vertical = Space.xs),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = selectedName,
                    style = type.body,
                    color = colors.textPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = "▾",
                    style = type.caption,
                    color = colors.textSecondary,
                )
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
            ) {
                DropdownMenuItem(
                    text = { Text("All tournaments") },
                    onClick = {
                        onSelected(null)
                        expanded = false
                    },
                )
                tournaments.forEach { (id, name) ->
                    DropdownMenuItem(
                        text = { Text(name) },
                        onClick = {
                            onSelected(id)
                            expanded = false
                        },
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Single-group card
// ---------------------------------------------------------------------------

@Composable
private fun SingleGroupCard(
    group: PublicGroupItem,
    joiningId: Int?,
    onOpen: () -> Unit,
    onJoin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val imageUrl = group.headerImageUrl ?: group.tournamentImageUrl

    SurfaceCard(
        modifier = modifier,
        imageUrl = imageUrl,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            KickerText(
                text = "★ ${(group.tournamentName ?: "").uppercase()}",
                color = Palette.orange,
            )
            Text(
                text = group.name,
                style = type.title2,
                color = colors.textPrimary,
            )
            if (!group.description.isNullOrBlank()) {
                Text(
                    text = group.description,
                    style = type.bodyRegular,
                    color = colors.textSecondary,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            GroupMeta(group = group)
            Spacer(Modifier.height(Space.xxs))
            GroupActionButton(
                group = group,
                joiningId = joiningId,
                compact = false,
                onOpen = onOpen,
                onJoin = onJoin,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Tournament bucket card (grouped mode)
// ---------------------------------------------------------------------------

@Composable
private fun TournamentBucketCard(
    bucket: BrowseCard.TournamentBucket,
    joiningId: Int?,
    onOpen: (Int) -> Unit,
    onJoin: (PublicGroupItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface),
    ) {
        // Tournament header image with overlay.
        if (bucket.tournamentImageUrl != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f),
            ) {
                AsyncImage(
                    model = bucket.tournamentImageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
                // Bottom scrim.
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Palette.ink.copy(alpha = 0.82f)),
                            )
                        ),
                )
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .fillMaxWidth()
                        .padding(Space.m),
                    verticalAlignment = Alignment.Bottom,
                ) {
                    KickerText(
                        text = "★ ${bucket.tournamentName.uppercase()}",
                        color = Palette.orange,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "${bucket.groups.size} GROUPS",
                        style = type.kicker,
                        color = Color.White,
                        modifier = Modifier
                            .clip(Radius.sharp)
                            .background(Palette.pillDark)
                            .padding(horizontal = Space.xs, vertical = Space.xxs),
                    )
                }
            }
        }

        // Rows for each group in the bucket.
        bucket.groups.forEachIndexed { index, group ->
            if (index > 0) {
                HorizontalDivider(color = colors.overlay04, thickness = 1.dp)
            }
            BucketGroupRow(
                group = group,
                joiningId = joiningId,
                onOpen = { onOpen(group.id) },
                onJoin = { onJoin(group) },
            )
        }
    }
}

@Composable
private fun BucketGroupRow(
    group: PublicGroupItem,
    joiningId: Int?,
    onOpen: () -> Unit,
    onJoin: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Space.s, horizontal = Space.l),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = group.name,
                style = type.headline,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(Space.xxs))
            GroupMeta(group = group)
        }
        Spacer(Modifier.width(Space.xs))
        GroupActionButton(
            group = group,
            joiningId = joiningId,
            compact = true,
            onOpen = onOpen,
            onJoin = onJoin,
        )
    }
}

// ---------------------------------------------------------------------------
// Shared components
// ---------------------------------------------------------------------------

@Composable
private fun GroupMeta(group: PublicGroupItem) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Row(
        horizontalArrangement = Arrangement.spacedBy(Space.xxs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val memberLabel = if (group.memberCount == 1) "MEMBER" else "MEMBERS"
        Text(
            text = "${group.memberCount} $memberLabel",
            style = type.kicker,
            color = colors.textMuted,
        )
        Text("·", style = type.kicker, color = colors.textMuted)
        Text(
            text = "${group.correctTeamPoints} / ${group.exactResultPoints} PTS",
            style = type.kicker,
            color = colors.textMuted,
        )
        if (group.isMember) {
            Text("·", style = type.kicker, color = colors.textMuted)
            Text(
                text = "✓ MEMBER",
                style = type.kicker,
                color = colors.accentPositive,
            )
        }
    }
}

@Composable
private fun GroupActionButton(
    group: PublicGroupItem,
    joiningId: Int?,
    compact: Boolean,
    onOpen: () -> Unit,
    onJoin: () -> Unit,
) {
    if (group.isMember) {
        BettyButton(
            text = if (compact) "OPEN →" else "OPEN GROUP →",
            onClick = onOpen,
            variant = if (compact) BettyButtonVariant.GHOST else BettyButtonVariant.OUTLINE,
            block = !compact,
            modifier = Modifier.testTag("browse-open"),
        )
    } else {
        val isJoining = joiningId == group.id
        BettyButton(
            text = when {
                isJoining && compact -> "…"
                isJoining -> "PLACING…"
                compact -> "BET →"
                else -> "BET HERE →"
            },
            onClick = onJoin,
            variant = BettyButtonVariant.PRIMARY,
            enabled = !isJoining,
            loading = isJoining,
            block = !compact,
            modifier = Modifier.testTag("browse-join"),
        )
    }
}

// ---------------------------------------------------------------------------
// Join outcome handler
// ---------------------------------------------------------------------------

private fun handleJoin(
    outcome: BrowseViewModel.JoinOutcome,
    @Suppress("UNUSED_PARAMETER") groupName: String,
    nav: AppNavigator,
    notify: NotifyCenter,
) {
    when (outcome) {
        is BrowseViewModel.JoinOutcome.Joined -> {
            notify.success("You are now a proud member of ${outcome.name}. Opening group…")
            nav.openGroup(outcome.groupId)
        }
        is BrowseViewModel.JoinOutcome.AlreadyMember -> {
            notify.info("You are already a member of ${outcome.name}.")
        }
        is BrowseViewModel.JoinOutcome.Blocked -> {
            notify.error("You have been blocked from ${outcome.name}.")
        }
        is BrowseViewModel.JoinOutcome.Unavailable -> {
            notify.error("This group is no longer public.")
        }
        is BrowseViewModel.JoinOutcome.Failed -> {
            notify.error("Could not join. Please try again.")
        }
    }
}
