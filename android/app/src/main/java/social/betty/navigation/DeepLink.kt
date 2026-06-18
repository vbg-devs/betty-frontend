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

    /** Reminder push → the bet sheet for a game (api-contract §3.2; iOS `.bet`). */
    data class Bet(val gameId: Int, val groupId: Int) : DeepLink

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
                // betty://bet/<groupId>/<gameId> — strict 2-segment match (mirrors iOS).
                "bet" -> {
                    val gid = segments.getOrNull(0)?.toIntOrNull()
                    val gameId = segments.getOrNull(1)?.toIntOrNull()
                    if (segments.size == 2 && gid != null && gameId != null) {
                        Bet(gameId = gameId, groupId = gid)
                    } else {
                        null
                    }
                }
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
            // Reminder push deep link: /groups/<groupId>/games/<gameId> (api-contract §3.2).
            // Strict positional match (mirrors iOS Router.swift) — no false JoinInvite overlap.
            if (segments.size == 4 && segments[0] == "groups" && segments[2] == "games") {
                val gid = segments[1].toIntOrNull()
                val gameId = segments[3].toIntOrNull()
                if (gid != null && gameId != null) return Bet(gameId = gameId, groupId = gid)
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
        // Mirror iOS Router.perform(.bet): HOME → group detail → bet sheet.
        is DeepLink.Bet -> {
            openGroup(link.groupId)
            present(Sheet.Bet(link.gameId, link.groupId))
        }
    }
}
