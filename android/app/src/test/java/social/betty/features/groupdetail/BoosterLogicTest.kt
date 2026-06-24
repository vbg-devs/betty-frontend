package social.betty.features.groupdetail

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.model.Bet
import social.betty.core.model.Game
import java.time.Instant

/**
 * Booster-related logic helpers (Boosters spec §3.4). Pure functions; no Compose required.
 */
class BoosterLogicTest {

    private val past: Instant = Instant.parse("2026-06-01T12:00:00Z")
    private val future: Instant = Instant.parse("2026-07-01T12:00:00Z")

    private fun game(id: Int, finished: Boolean, start: Instant = past) =
        Game(
            id = id,
            tournamentId = 1,
            poolId = 1,
            homeTeamId = 10,
            awayTeamId = 20,
            startDate = start,
            status = if (finished) 1 else null,
        )

    private fun bet(
        id: Int = 1,
        gameId: Int = 100,
        userId: String = "me",
        userPoints: Int? = null,
        boosted: Boolean = false,
    ) = Bet(
        id = id,
        userId = userId,
        gameId = gameId,
        groupId = 1,
        userPoints = userPoints,
        homeTeamScore = 0,
        awayTeamScore = 0,
        boosted = boosted,
    )

    @Test
    fun `awardedBoosted true only when game finished, own bet boosted, and points greater than zero`() {
        val finished = game(100, finished = true)
        val unfinished = game(100, finished = false, start = future)

        // Happy path.
        assertTrue(
            GroupGameCardLogic.awardedBoosted(
                finished,
                listOf(bet(boosted = true, userPoints = 6)),
                "me",
            ),
        )

        // Game not finished — false (the pre-kickoff rocket is handled elsewhere).
        assertFalse(
            GroupGameCardLogic.awardedBoosted(
                unfinished,
                listOf(bet(boosted = true, userPoints = 6)),
                "me",
            ),
        )

        // Not boosted — false.
        assertFalse(
            GroupGameCardLogic.awardedBoosted(
                finished,
                listOf(bet(boosted = false, userPoints = 6)),
                "me",
            ),
        )

        // Boosted but zero points — false (spec §2.5 suppression).
        assertFalse(
            GroupGameCardLogic.awardedBoosted(
                finished,
                listOf(bet(boosted = true, userPoints = 0)),
                "me",
            ),
        )

        // No own bet — false.
        assertFalse(
            GroupGameCardLogic.awardedBoosted(
                finished,
                listOf(bet(userId = "someone-else", boosted = true, userPoints = 6)),
                "me",
            ),
        )

        // Logged out — false.
        assertFalse(
            GroupGameCardLogic.awardedBoosted(
                finished,
                listOf(bet(boosted = true, userPoints = 6)),
                null,
            ),
        )
    }
}
