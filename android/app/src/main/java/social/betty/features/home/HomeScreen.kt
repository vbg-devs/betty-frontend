package social.betty.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import social.betty.core.logic.Dashboard
import social.betty.core.logic.DashboardGroup
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.CountPill
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard
import social.betty.designsystem.components.TogglePills
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalNavigator
import social.betty.navigation.Sheet
import social.betty.navigation.Tab
import java.time.Instant

@Composable
fun HomeScreen() {
    val container = LocalAppContainer.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()

    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val tournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    val showGrouped by container.preferences.showGrouped.collectAsStateWithLifecycle()

    var selectedTab by remember { mutableStateOf(HomeTab.RUNNING) }
    var isRefreshing by remember { mutableStateOf(false) }

    val doRefresh: () -> Unit = {
        scope.launch {
            isRefreshing = true
            try {
                // Reload both stores in parallel; ignore individual errors (boot already
                // loaded them; a transient failure just keeps the last-good data).
                coroutineScope {
                    launch { runCatching { container.groupStore.load() } }
                    launch { runCatching { container.tournamentStore.load() } }
                }
            } finally {
                isRefreshing = false
            }
        }
    }

    HomeScreenContent(
        groups = groups.let { g ->
            val now = Instant.now()
            Dashboard.enrich(g, tournaments, now)
        },
        selectedTab = selectedTab,
        showGrouped = showGrouped,
        isRefreshing = isRefreshing,
        onTabSelected = { selectedTab = it },
        onSetGrouped = { container.preferences.setShowGrouped(it) },
        onRefresh = doRefresh,
        onNewGroup = { nav.present(Sheet.CreateGroup) },
        onBrowse = { nav.selectTab(Tab.BROWSE) },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreenContent(
    groups: List<DashboardGroup>,
    selectedTab: HomeTab,
    showGrouped: Boolean,
    isRefreshing: Boolean,
    onTabSelected: (HomeTab) -> Unit,
    onSetGrouped: (Boolean) -> Unit,
    onRefresh: () -> Unit,
    onNewGroup: () -> Unit,
    onBrowse: () -> Unit,
) {
    val runningCards = remember(groups) { Dashboard.runningTab(groups) }
    val endedCards = remember(groups) { Dashboard.endedTab(groups) }
    val visibleCards = if (selectedTab == HomeTab.RUNNING) runningCards else endedCards

    BettyScaffold(modifier = Modifier.testTag("home-screen")) {
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(Space.m),
                verticalArrangement = Arrangement.spacedBy(Space.m),
            ) {
                // Group list or global empty state
                if (groups.isEmpty()) {
                    GlobalEmptyState(onNewGroup = onNewGroup, onBrowse = onBrowse)
                } else {
                    // Running/Ended tabs row + grouping toggle in a horizontal bar
                    HomeTabsRow(
                        selectedTab = selectedTab,
                        runningCount = runningCards.size,
                        endedCount = endedCards.size,
                        showGrouped = showGrouped,
                        onTabSelected = onTabSelected,
                        onSetGrouped = onSetGrouped,
                    )

                    // Cards or per-tab empty copy
                    if (visibleCards.isEmpty()) {
                        TabEmptyState(tab = selectedTab)
                    } else {
                        val layoutItems = Dashboard.layout(visibleCards, showGrouped)
                        layoutItems.forEach { item ->
                            DashboardItemCard(item = item)
                        }
                    }

                    // 3. Hero card below the list: headline + countdown + CTAs
                    HomeHeroCard(
                        allCards = groups,
                        selectedTab = selectedTab,
                        onNewGroup = onNewGroup,
                        onBrowse = onBrowse,
                    )
                }

                Spacer(Modifier.height(Space.xxl))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Hero card
// ---------------------------------------------------------------------------

@Composable
private fun HomeHeroCard(
    allCards: List<DashboardGroup>,
    selectedTab: HomeTab,
    onNewGroup: () -> Unit,
    onBrowse: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    // One-second ticker drives both headline counts and countdown.
    var nowEpochMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000L)
            nowEpochMs = System.currentTimeMillis()
        }
    }
    val nowInstant = remember(nowEpochMs) { Instant.ofEpochMilli(nowEpochMs) }

    // Re-derive enriched cards on each tick (start/end dates move relative to now).
    val runningCards = remember(allCards, nowEpochMs) { Dashboard.runningTab(allCards) }
    val endedCards = remember(allCards, nowEpochMs) { Dashboard.endedTab(allCards) }
    val visibleCount = if (selectedTab == HomeTab.RUNNING) runningCards.size else endedCards.size
    val headline = homeHeadline(
        visibleCount = visibleCount,
        totalCount = allCards.size,
        tab = selectedTab,
    )
    val countdown = remember(allCards, nowEpochMs) {
        Dashboard.countdownTarget(allCards, nowInstant)
    }

    SurfaceCard(modifier = Modifier.testTag("home-hero")) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            KickerText(text = "★ YOUR GROUPS", color = Palette.orange)

            // Headline
            HeadlineText(headline = headline)

            // Countdown (hidden once every running tournament has kicked off)
            if (countdown != null) {
                HomeCountdownPanel(
                    tournamentName = countdown.tournamentName,
                    target = countdown.startDate,
                    now = nowInstant,
                )
            }

            // + NEW GROUP
            BettyButton(
                text = "+ NEW GROUP",
                onClick = onNewGroup,
                variant = BettyButtonVariant.PRIMARY,
                block = true,
                modifier = Modifier.testTag("home-new-group"),
            )

            // OR BROWSE PUBLIC GROUPS →
            Text(
                text = "OR BROWSE PUBLIC GROUPS →",
                style = type.kicker,
                color = colors.textPrimary,
                modifier = Modifier
                    .clickable(onClick = onBrowse)
                    .testTag("home-browse-link"),
            )
        }
    }
}

@Composable
private fun HeadlineText(headline: HomeHeadline) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val annotated = buildAnnotatedString {
        when (headline) {
            is HomeHeadline.Groups -> {
                val count = headline.count
                withStyle(SpanStyle(color = colors.textPrimary)) { append("$count ") }
                withStyle(SpanStyle(color = colors.accentPositive)) {
                    append(if (count == 1) "GROUP." else "GROUPS.")
                }
                append("\n")
                withStyle(SpanStyle(color = Palette.orange)) { append("ONE CHAMPION.") }
            }
            HomeHeadline.NoneRunning -> {
                withStyle(SpanStyle(color = colors.textPrimary)) { append("NO RUNNING\n") }
                withStyle(SpanStyle(color = colors.accentPositive)) { append("GROUPS.") }
            }
            HomeHeadline.NoneEnded -> {
                withStyle(SpanStyle(color = colors.textPrimary)) { append("NO ENDED\n") }
                withStyle(SpanStyle(color = colors.accentPositive)) { append("GROUPS.") }
            }
            HomeHeadline.Empty -> {
                withStyle(SpanStyle(color = colors.textPrimary)) { append("NO GROUPS\n") }
                withStyle(SpanStyle(color = colors.accentPositive)) { append("YET.") }
            }
        }
    }
    Text(
        text = annotated,
        style = type.displayL,
    )
}

// ---------------------------------------------------------------------------
// Countdown panel
// ---------------------------------------------------------------------------

@Composable
private fun HomeCountdownPanel(
    tournamentName: String,
    target: Instant,
    now: Instant,
) {
    val colors = BettyTheme.colors
    val parts = CountdownParts.until(target, now)

    InsetPanel(
        accent = colors.accentPositive,
        modifier = Modifier.testTag("home-countdown"),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            KickerText(text = "● FIRST KICKOFF IN", color = colors.accentPositive)
            Spacer(Modifier.height(Space.xs))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Space.xxs),
            ) {
                CountdownCell(CountdownParts.pad(parts.days), "DAYS", false, Modifier.weight(1f))
                CountdownCell(CountdownParts.pad(parts.hours), "HRS", false, Modifier.weight(1f))
                CountdownCell(CountdownParts.pad(parts.minutes), "MIN", false, Modifier.weight(1f))
                CountdownCell(CountdownParts.pad(parts.seconds), "SEC", true, Modifier.weight(1f))
            }
            Spacer(Modifier.height(Space.xs))
            KickerText(text = "★ $tournamentName", color = Palette.orange)
        }
    }
}

@Composable
private fun CountdownCell(
    value: String,
    unit: String,
    accent: Boolean,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = modifier
            .background(colors.overlay04, shape = RoundedCornerShape(2.dp))
            .padding(vertical = Space.xs),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = value,
            style = type.score,
            color = if (accent) colors.accentPositive else colors.textPrimary,
        )
        Text(
            text = unit,
            style = type.micro,
            color = colors.textMuted,
        )
    }
}

// ---------------------------------------------------------------------------
// Tabs row — custom so each tab gets its own stable test tag for e2e
// ---------------------------------------------------------------------------

@Composable
private fun HomeTabsRow(
    selectedTab: HomeTab,
    runningCount: Int,
    endedCount: Int,
    showGrouped: Boolean,
    onTabSelected: (HomeTab) -> Unit,
    onSetGrouped: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // RUNNING tab
        HomeTabButton(
            label = "RUNNING",
            count = runningCount,
            isActive = selectedTab == HomeTab.RUNNING,
            onClick = { onTabSelected(HomeTab.RUNNING) },
            modifier = Modifier.testTag("home-tab-running"),
        )
        Spacer(Modifier.width(Space.s))
        // ENDED tab
        HomeTabButton(
            label = "ENDED",
            count = endedCount,
            isActive = selectedTab == HomeTab.ENDED,
            onClick = { onTabSelected(HomeTab.ENDED) },
            modifier = Modifier.testTag("home-tab-ended"),
        )
        Spacer(Modifier.weight(1f))
        // Grouped/List toggle
        TogglePills(
            options = listOf("GROUPED", "LIST"),
            selectedIndex = if (showGrouped) 0 else 1,
            onSelect = { idx -> onSetGrouped(idx == 0) },
            modifier = Modifier.testTag("home-grouping-toggle"),
        )
    }
}

@Composable
private fun HomeTabButton(
    label: String,
    count: Int,
    isActive: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = modifier
            // Size to content so the fillMaxWidth underline below spans only the tab's
            // label+pill — not the whole row (which squeezed the ENDED tab to a vertical sliver).
            .width(IntrinsicSize.Max)
            .clickable(onClick = onClick)
            .padding(vertical = Space.xs),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = label.uppercase(),
                style = type.caption,
                color = if (isActive) colors.textPrimary else colors.textMuted,
            )
            Spacer(Modifier.width(Space.xxs))
            CountPill(count = count, isActive = isActive)
        }
        // 3dp orange underline when active, consistent height otherwise
        Spacer(Modifier.height(2.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(3.dp)
                .clip(Radius.sharp)
                .background(if (isActive) Palette.orange else colors.overlay04.copy(alpha = 0f)),
        )
    }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

@Composable
private fun GlobalEmptyState(
    onNewGroup: () -> Unit,
    onBrowse: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    SurfaceCard(modifier = Modifier.testTag("home-empty")) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            KickerText(text = "★ GET STARTED", color = Palette.orange)
            val annotated = buildAnnotatedString {
                withStyle(SpanStyle(color = colors.textPrimary)) { append("SIX FRIENDS.\n") }
                withStyle(SpanStyle(color = Palette.orange)) { append("ONE GROUP.") }
            }
            Text(
                text = annotated,
                style = type.displayL,
            )
            Text(
                text = "Invite a bunch of friends and start your first group for the next cup.",
                style = type.bodyRegular,
                color = colors.textBody,
            )
            Spacer(Modifier.height(Space.xs))
            BettyButton(
                text = "+ START A GROUP",
                onClick = onNewGroup,
                variant = BettyButtonVariant.PRIMARY,
                block = true,
            )
            Text(
                text = "OR JOIN A PUBLIC GROUP →",
                style = type.kicker,
                color = colors.textPrimary,
                modifier = Modifier.clickable(onClick = onBrowse),
            )
        }
    }
}

@Composable
private fun TabEmptyState(tab: HomeTab) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    SurfaceCard {
        Column(modifier = Modifier.fillMaxWidth()) {
            KickerText(
                text = if (tab == HomeTab.RUNNING) "○ NOTHING RUNNING" else "○ NOTHING WRAPPED",
                color = colors.textMuted,
            )
            Spacer(Modifier.height(Space.xs))
            Text(
                text = if (tab == HomeTab.RUNNING) {
                    "No active tournaments right now. Check the Ended tab to revisit past groups."
                } else {
                    "No tournaments have wrapped up yet. Recently-ended groups stay in Running for four weeks."
                },
                style = type.bodyRegular,
                color = colors.textBody,
            )
        }
    }
}
