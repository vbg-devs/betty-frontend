package social.betty.core.logic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Pool
import social.betty.core.model.Tournament
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

class GameScheduleTest {

    private val zone: ZoneId = ZoneId.of("UTC")
    private val now: Instant = Instant.parse("2026-06-08T12:00:00Z")

    private fun game(id: Int, poolId: Int, start: Instant, status: Int? = null) =
        Game(id = id, poolId = poolId, startDate = start, status = status)

    @Test
    fun `isLive only within 150 minutes after kickoff and not finished`() {
        assertTrue(GameSchedule.isLive(game(1, 1, now.minus(30, ChronoUnit.MINUTES)), now))
        assertFalse("before kickoff", GameSchedule.isLive(game(2, 1, now.plus(10, ChronoUnit.MINUTES)), now))
        assertFalse("past the 150m window", GameSchedule.isLive(game(3, 1, now.minus(3, ChronoUnit.HOURS)), now))
        assertFalse("finished", GameSchedule.isLive(game(4, 1, now.minus(30, ChronoUnit.MINUTES), status = 1), now))
    }

    @Test
    fun `kickoff label is Today, Tomorrow, or near-term relative`() {
        assertTrue(GameSchedule.kickoffLabel(now.plus(2, ChronoUnit.HOURS), now, zone).startsWith("in "))
        assertTrue(GameSchedule.kickoffLabel(now.plus(8, ChronoUnit.HOURS), now, zone).startsWith("Today"))
        assertTrue(GameSchedule.kickoffLabel(now.plus(28, ChronoUnit.HOURS), now, zone).startsWith("Tomorrow"))
    }

    @Test
    fun `group buckets games by calendar day, joins pool names, flags next upcoming`() {
        val detail = Tournament(
            id = 1, name = "T1",
            pools = listOf(Pool(1, 1, "Group A"), Pool(2, 1, "Group B")),
            games = listOf(
                game(1, 1, now.minus(1, ChronoUnit.DAYS)),          // yesterday
                game(2, 1, now.plus(3, ChronoUnit.HOURS)),          // today, pool A
                game(3, 2, now.plus(5, ChronoUnit.HOURS)),          // today, pool B
                game(4, 1, now.plus(2, ChronoUnit.DAYS)),           // +2 days
            ),
        )
        val myBet = Bet(id = 9, userId = "me", gameId = 2, groupId = 1, homeTeamScore = 1, awayTeamScore = 0)
        val groups = GameSchedule.group(detail, listOf(myBet), uid = "me", now = now, zone = zone)

        assertEquals(3, groups.size)
        val today = groups.first { it.title == "Today" }
        assertEquals("Group A & Group B", today.poolNames)
        assertTrue("today holds the next future game", today.isNextUpcoming)
        // only the next-upcoming day is flagged
        assertEquals(1, groups.count { it.isNextUpcoming })

        val betGame = today.games.first { it.game.id == 2 }
        assertTrue(betGame.hasBet)
        assertEquals(1, betGame.myHome)
        assertEquals(0, betGame.myAway)
        assertEquals(1, betGame.betCount)
    }
}
