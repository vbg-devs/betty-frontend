package social.betty.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.mutableStateListOf

/**
 * Compose-state navigation model (the iOS `Router` analogue): five tabs, a per-tab push
 * stack, and a single active sheet. Re-selecting the current tab pops it to root (iOS tab
 * behavior). Owned by [RootScreen] via `remember`.
 */
class AppNavigator {
    var currentTab by mutableStateOf(Tab.HOME)
        private set

    private val stacks: Map<Tab, SnapshotStateList<Route>> =
        Tab.entries.associateWith { mutableStateListOf() }

    var sheet by mutableStateOf<Sheet?>(null)
        private set

    fun stackFor(tab: Tab): SnapshotStateList<Route> = stacks.getValue(tab)
    fun currentStack(): SnapshotStateList<Route> = stacks.getValue(currentTab)

    fun selectTab(tab: Tab) {
        if (tab == currentTab) currentStack().clear() else currentTab = tab
    }

    fun push(route: Route) {
        currentStack().add(route)
    }

    /** Pops the current tab's stack; returns false when already at root. */
    fun pop(): Boolean {
        val stack = currentStack()
        if (stack.isEmpty()) return false
        stack.removeAt(stack.lastIndex)
        return true
    }

    fun present(sheet: Sheet) {
        this.sheet = sheet
    }

    fun dismissSheet() {
        sheet = null
    }

    // Convenience entry points used by deep links / cross-tab navigation.
    fun openGroup(groupId: Int) {
        currentTab = Tab.HOME
        val home = stackFor(Tab.HOME)
        home.clear()
        home.add(Route.GroupDetail(groupId))
    }

    fun openLeaderboard() {
        currentTab = Tab.LEADERBOARD
    }
}
