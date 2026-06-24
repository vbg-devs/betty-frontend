package social.betty.navigation

/** Bottom tabs (screens.md §2). */
enum class Tab(val title: String, val testTag: String) {
    HOME("Home", "tab-home"),
    BROWSE("Browse", "tab-browse"),
    LEADERBOARD("Board", "tab-leaderboard"),
    ACTIVITY("Activity", "tab-activity"),
    PROFILE("Profile", "tab-profile"),
}

/** Pushed (full-screen) destinations within a tab's navigation stack. */
sealed interface Route {
    data class GroupDetail(val groupId: Int) : Route
    data object AdminEvaluate : Route
    data object Support : Route
    data object About : Route
}

/** Modal presentations (web modals → bottom sheets / full covers). */
sealed interface Sheet {
    data object CreateGroup : Sheet
    data class JoinInvite(val code: String) : Sheet
    data class Bet(val gameId: Int, val groupId: Int) : Sheet
    data class UserHistory(val groupId: Int, val userId: String) : Sheet
    data class GroupSettings(val groupId: Int) : Sheet
}
