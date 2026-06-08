package social.betty.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
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

/** The 5-tab shell (screens.md §2): tab content + per-tab push stack + the active sheet. */
@Composable
fun MainScaffold() {
    val nav = LocalNavigator.current
    val colors = BettyTheme.colors

    BackHandler(enabled = nav.currentTab != Tab.HOME && nav.currentStack().isEmpty()) {
        nav.selectTab(Tab.HOME)
    }

    Box(modifier = Modifier.fillMaxSize().background(colors.background)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                TabContent(nav)
            }
            BettyBottomBar(nav)
        }
        SheetHost(nav)
    }
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

@Composable
private fun BettyBottomBar(nav: AppNavigator) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val container = LocalAppContainer.current
    val unseen by container.activityFeed.unseen.collectAsStateWithLifecycle()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surfaceDeep)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tab.entries.forEach { tab ->
            val active = nav.currentTab == tab && nav.currentStack().isEmpty()
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .testTag(tab.testTag)
                    .clickable { nav.selectTab(tab) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = tab.title.uppercase(),
                    style = type.caption.copy(
                        color = if (active) Palette.orange else colors.textMuted,
                    ),
                    textAlign = TextAlign.Center,
                )
                if (tab == Tab.ACTIVITY && unseen > 0) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = Space.xs)
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(Palette.alertRed)
                            .testTag("activity-badge"),
                    )
                }
            }
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
