package social.betty.mock.scenarios

import social.betty.mock.DefaultScenario
import social.betty.mock.MockBet
import social.betty.mock.MockMember
import social.betty.mock.MockScenario
import java.time.Instant

// Group-detail suite fixtures — small, composable tweaks layered onto DefaultScenario via
// `withScenario` BEFORE `launchApp()`.

/** Flips `allow_sneak_peek` on a group (default: Sunday Legends). */
fun MockScenario.groupDetailSetSneakPeek(
    allowed: Boolean,
    groupId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID,
) {
    updateGroup(groupId) { it.allowSneakPeek = allowed }
}

/** Adds a bet with explicit evaluation state (processed bets carry points). */
fun MockScenario.groupDetailAddBet(
    userId: String,
    gameId: Int,
    groupId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID,
    home: Int,
    away: Int,
    points: Int? = null,
    processed: Boolean = false,
) {
    val bet = MockBet(
        id = nextBetId,
        userId = userId,
        gameId = gameId,
        groupId = groupId,
        userPoints = points,
        homeTeamScore = home,
        awayTeamScore = away,
        processedAt = if (processed) Instant.now().minusSeconds(3600) else null,
        createdAt = Instant.now().minusSeconds(86_400),
    )
    nextBetId += 1
    bets.add(bet)
}

/** Overrides a member's score (drives dense-ranking/tie fixtures). */
fun MockScenario.groupDetailSetMemberScore(
    userId: String,
    score: Int,
    groupId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID,
) {
    updateMember(groupId, userId) {
        it.score = score
        it.normalizedScore = score.toDouble()
    }
}

/** Appends an extra active participant (top-3 cutoff fixtures). */
fun MockScenario.groupDetailAddMember(
    userId: String,
    score: Int,
    groupId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID,
) {
    updateGroup(groupId) {
        it.members.add(MockMember(userId = userId, score = score, normalizedScore = score.toDouble(), accessLevel = 2))
    }
}

/**
 * Sets/clears a group's committed cover image (flips the author CTA between "+ ADD COVER" and
 * "CHANGE COVER →").
 */
fun MockScenario.groupDetailSetHeaderImage(
    url: String?,
    groupId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID,
) {
    updateGroup(groupId) { it.headerImageUrl = url }
}

/**
 * Renames the running tournament's pools in order (pool-name header fixtures — names containing
 * "Group" collapse the schedule header to the day title only).
 */
fun MockScenario.groupDetailRenamePools(
    names: List<String>,
    tournamentId: Int = DefaultScenario.RUNNING_TOURNAMENT_ID,
) {
    val tournament = tournaments.firstOrNull { it.id == tournamentId } ?: return
    names.forEachIndexed { index, name ->
        if (index < tournament.pools.size) tournament.pools[index].name = name
    }
}
