package social.betty.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.features.activity.ActivityFeedScreen
import social.betty.features.admin.AdminEvaluateScreen
import social.betty.features.browse.BrowseScreen
import social.betty.features.creategroup.CreateGroupSheet
import social.betty.features.groupdetail.BetSheet
import social.betty.features.groupdetail.GroupDetailScreen
import social.betty.features.groupdetail.GroupSettingsSheet
import social.betty.features.groupdetail.UserHistorySheet
import social.betty.features.home.HomeScreen
import social.betty.features.join.JoinInviteSheet
import social.betty.features.leaderboard.GlobalLeaderboardScreen
import social.betty.features.profile.AboutScreen
import social.betty.features.profile.ProfileScreen
import social.betty.features.profile.SupportScreen

/**
 * The 5-tab shell (screens.md §2): an M3 [Scaffold] with a branded [TopAppBar] + [NavigationBar]
 * around the active tab's content (per-tab push stack), plus the active modal sheet overlaid.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScaffold() {
    val nav = LocalNavigator.current
    val colors = BettyTheme.colors

    BackHandler(enabled = nav.currentTab != Tab.HOME && nav.currentStack().isEmpty()) {
        nav.selectTab(Tab.HOME)
    }

    Box(modifier = Modifier.fillMaxSize().background(colors.background)) {
        Scaffold(
            topBar = { BettyTopBar(nav) },
            bottomBar = { BettyBottomBar(nav) },
            containerColor = colors.background,
        ) { innerPadding ->
            // consumeWindowInsets so each screen's BettyScaffold (WindowInsets.systemBars)
            // doesn't re-apply the status/nav-bar inset the chrome already handled.
            Box(
                modifier = Modifier
                    .padding(innerPadding)
                    .consumeWindowInsets(innerPadding)
                    .fillMaxSize(),
            ) {
                TabContent(nav)
            }
        }
        SheetHost(nav)
    }
}

/** Tab/route title + back affordance. Pushed routes show a back arrow; tab roots show the tab name. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BettyTopBar(nav: AppNavigator) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val top = nav.currentStack().lastOrNull()
    // The Home tab root shows the Betty wordmark logo; every other destination shows a
    // centered title. (Wordmark = lowercase "betty" in the display face, as on the auth/splash.)
    val isHomeRoot = top == null && nav.currentTab == Tab.HOME

    CenterAlignedTopAppBar(
        title = {
            if (isHomeRoot) {
                Text(
                    text = "betty",
                    style = type.title2,
                    color = colors.textPrimary,
                    modifier = Modifier.testTag("topbar-logo"),
                )
            } else {
                val title = when (top) {
                    is Route.GroupDetail -> "Group"
                    Route.AdminEvaluate -> "Evaluate"
                    Route.Support -> "Support"
                    Route.About -> "About"
                    null -> nav.currentTab.title
                }
                Text(
                    text = title.uppercase(),
                    style = type.headline,
                    color = colors.textPrimary,
                )
            }
        },
        navigationIcon = {
            if (top != null) {
                IconButton(onClick = { nav.pop() }, modifier = Modifier.testTag("topbar-back")) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = colors.textPrimary,
                    )
                }
            }
        },
        colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
            containerColor = colors.surfaceDeep,
            titleContentColor = colors.textPrimary,
            navigationIconContentColor = colors.textPrimary,
        ),
        modifier = Modifier.testTag("topbar"),
    )
}

@Composable
private fun TabContent(nav: AppNavigator) {
    val top = nav.currentStack().lastOrNull()
    if (top != null) {
        BackHandler(enabled = true) { nav.pop() }
        when (top) {
            is Route.GroupDetail -> GroupDetailScreen(groupId = top.groupId)
            Route.AdminEvaluate -> AdminEvaluateScreen()
            Route.Support -> SupportScreen()
            Route.About -> AboutScreen()
        }
    } else {
        when (nav.currentTab) {
            Tab.HOME -> HomeScreen()
            Tab.BROWSE -> BrowseScreen()
            Tab.LEADERBOARD -> GlobalLeaderboardScreen()
            Tab.ACTIVITY -> ActivityFeedScreen()
            Tab.PROFILE -> ProfileScreen()
        }
    }
}

private fun iconFor(tab: Tab): ImageVector = when (tab) {
    Tab.HOME -> Icons.Filled.Home
    Tab.BROWSE -> Icons.Filled.Search
    Tab.LEADERBOARD -> Icons.Filled.Star
    Tab.ACTIVITY -> Icons.Filled.Notifications
    Tab.PROFILE -> Icons.Filled.Person
}

@Composable
private fun BettyBottomBar(nav: AppNavigator) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val container = LocalAppContainer.current
    val unseen by container.activityFeed.unseen.collectAsStateWithLifecycle()

    NavigationBar(containerColor = colors.surfaceDeep) {
        Tab.entries.forEach { tab ->
            val active = nav.currentTab == tab && nav.currentStack().isEmpty()
            NavigationBarItem(
                selected = active,
                onClick = { nav.selectTab(tab) },
                icon = {
                    if (tab == Tab.ACTIVITY && unseen > 0) {
                        BadgedBox(
                            badge = {
                                Badge(
                                    containerColor = Palette.alertRed,
                                    modifier = Modifier.testTag("activity-badge"),
                                )
                            },
                        ) {
                            Icon(iconFor(tab), contentDescription = tab.title)
                        }
                    } else {
                        Icon(iconFor(tab), contentDescription = tab.title)
                    }
                },
                label = { Text(tab.title.uppercase(), style = type.micro) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = Palette.orange,
                    selectedTextColor = Palette.orange,
                    indicatorColor = Palette.orangeTint18,
                    unselectedIconColor = colors.textMuted,
                    unselectedTextColor = colors.textMuted,
                ),
                modifier = Modifier.testTag(tab.testTag),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SheetHost(nav: AppNavigator) {
    val sheet = nav.sheet ?: return
    val colors = BettyTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val dismiss: () -> Unit = { nav.dismissSheet() }

    ModalBottomSheet(
        onDismissRequest = dismiss,
        sheetState = sheetState,
        containerColor = colors.surface,
        contentColor = colors.textPrimary,
        dragHandle = null,
    ) {
        when (sheet) {
            Sheet.CreateGroup -> CreateGroupSheet(onDismiss = dismiss)
            is Sheet.JoinInvite -> JoinInviteSheet(code = sheet.code, onDismiss = dismiss)
            is Sheet.Bet -> BetSheet(gameId = sheet.gameId, groupId = sheet.groupId, onDismiss = dismiss)
            is Sheet.UserHistory -> UserHistorySheet(groupId = sheet.groupId, userId = sheet.userId, onDismiss = dismiss)
            is Sheet.GroupSettings -> GroupSettingsSheet(groupId = sheet.groupId, onDismiss = dismiss)
        }
    }
}
