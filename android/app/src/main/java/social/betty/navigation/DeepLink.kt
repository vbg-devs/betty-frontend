package social.betty.navigation

import android.net.Uri

/**
 * Deep links (screens.md §4). Invite links are the one critical path; the app generates
 * `https://betty.social/dashboard/groups/join/{code}` and the `betty://` scheme mirrors it.
 * Mirrors `safeReturnUrl` strictness — only the known patterns are honored, everything else
 * is ignored.
 */
sealed interface DeepLink {
    data class JoinInvite(val code: String) : DeepLink
    data class Group(val id: Int) : DeepLink
    data class Leaderboard(val tournamentId: Int) : DeepLink
    data object Dashboard : DeepLink

    companion object {
        fun parse(raw: String?): DeepLink? {
            val uri = raw?.let { runCatching { Uri.parse(it) }.getOrNull() } ?: return null
            return when (uri.scheme) {
                "betty" -> parseCustomScheme(uri)
                "https" -> parseUniversal(uri)
                else -> null
            }
        }

        private fun parseCustomScheme(uri: Uri): DeepLink? {
            val segments = uri.pathSegments
            return when (uri.host) {
                "join" -> segments.firstOrNull()?.takeIf { it.isNotBlank() }?.let { JoinInvite(it) }
                "group" -> segments.firstOrNull()?.toIntOrNull()?.let { Group(it) }
                "leaderboard" -> segments.firstOrNull()?.toIntOrNull()?.let { Leaderboard(it) }
                "dashboard" -> Dashboard
                else -> null
            }
        }

        private fun parseUniversal(uri: Uri): DeepLink? {
            if (uri.host != "betty.social") return null
            val segments = uri.pathSegments // /dashboard/groups/join/{code}
            val joinIdx = segments.indexOf("join")
            if (joinIdx >= 0 && joinIdx + 1 < segments.size) {
                return JoinInvite(segments[joinIdx + 1])
            }
            return null
        }
    }
}

fun AppNavigator.apply(link: DeepLink) {
    when (link) {
        is DeepLink.JoinInvite -> present(Sheet.JoinInvite(link.code))
        is DeepLink.Group -> openGroup(link.id)
        is DeepLink.Leaderboard -> openLeaderboard()
        DeepLink.Dashboard -> selectTab(Tab.HOME)
    }
}
