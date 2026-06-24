package social.betty.mock.scenarios

import org.json.JSONArray
import org.json.JSONObject
import social.betty.mock.BettyMockBackend
import social.betty.mock.DefaultScenario
import social.betty.mock.MembershipStatus
import social.betty.mock.MockGame
import social.betty.mock.MockHttpResponse
import social.betty.mock.MockScenario
import social.betty.mock.MockWire
import java.time.Instant

// Home-area fixture helpers layered on DefaultScenario.

/**
 * Removes the user from every group so `/user/:id/groups` answers an empty list (the dashboard
 * global empty state).
 */
fun MockScenario.homeRemoveAllMemberships(userId: String) {
    for (group in groups) {
        group.members.removeAll { it.userId == userId }
    }
}

fun MockScenario.homeRemoveMembership(userId: String, groupId: Int) {
    updateGroup(groupId) { group -> group.members.removeAll { it.userId == userId } }
}

/**
 * Pushes the ended tournament past the 28-day recently-ended window so its groups classify into
 * the Ended tab instead of Running + JUST ENDED.
 */
fun MockScenario.homeEndTournamentBeyondRecentWindow(tournamentId: Int) {
    homeSetTournamentDates(
        tournamentId,
        start = Instant.now().minusSeconds(70 * 86_400),
        end = Instant.now().minusSeconds(40 * 86_400),
    )
}

fun MockScenario.homeSetTournamentDates(tournamentId: Int, start: Instant? = null, end: Instant? = null) {
    val tournament = tournaments.firstOrNull { it.id == tournamentId } ?: return
    if (start != null) tournament.startDate = start
    if (end != null) tournament.endDate = end
}

/** Adds an un-bet, unfinished game to the running tournament (need-action input). */
fun MockScenario.homeAddUpcomingGame(
    id: Int,
    startingInSeconds: Long,
    homeTeamId: Int = 102,
    awayTeamId: Int = 104,
) {
    val tournament = tournaments.firstOrNull { it.id == DefaultScenario.RUNNING_TOURNAMENT_ID } ?: return
    tournament.games.add(
        MockGame(
            id = id,
            tournamentId = DefaultScenario.RUNNING_TOURNAMENT_ID,
            poolId = 1,
            homeTeamId = homeTeamId,
            awayTeamId = awayTeamId,
            startDate = Instant.now().plusSeconds(startingInSeconds),
            status = null,
        ),
    )
}

/**
 * Bets the game for the user in every group they're an active member of — the need-action banner
 * treats a game as bet only when each surfacing group has a bet.
 */
fun MockScenario.homeBetEverywhere(userId: String, gameId: Int, home: Int, away: Int) {
    for (group in groups.filter { it.isActiveMember(userId) }) {
        upsertBet(userId, gameId, group.id, home, away)
    }
}

/**
 * Re-registers the stock `/user/:id/groups` handler (LAST registration wins) — recovers the route
 * after a test forced it to fail.
 */
fun BettyMockBackend.homeRestoreUserGroupsRoute() {
    api("GET", "/user/:id/groups") { _, params, _, scenario ->
        val id = params["id"]
        val user = id?.let { scenario.user(it) }
        if (user == null || !user.hasProfile) return@api MockHttpResponse.empty(404)
        val placements = JSONArray()
        for (group in scenario.groups) {
            val member = group.member(id) ?: continue
            if (member.status != MembershipStatus.ACTIVE) continue
            placements.put(MockWire.placement(group, member, scenario))
        }
        val root = JSONObject()
        root.put("user", MockWire.user(user))
        root.put("groups", placements)
        MockHttpResponse.json(root)
    }
}
