package social.betty.core.logic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.model.Group
import social.betty.core.model.Tournament
import java.time.Instant
import java.time.temporal.ChronoUnit

class DashboardTest {

    private val now: Instant = Instant.parse("2026-06-08T12:00:00Z")

    private fun group(id: Int, tournamentId: Int, header: String? = null) =
        Group(id = id, name = "G$id", tournamentId = tournamentId, headerImageUrl = header)

    private fun tournament(id: Int, start: Instant?, end: Instant?) =
        Tournament(id = id, name = "T$id", startDate = start, endDate = end)

    @Test
    fun `ended when no tournament or end before now - recentlyEnded within 28 days`() {
        val running = tournament(1, now.minus(2, ChronoUnit.DAYS), now.plus(5, ChronoUnit.DAYS))
        val justEnded = tournament(2, now.minus(40, ChronoUnit.DAYS), now.minus(3, ChronoUnit.DAYS))
        val longEnded = tournament(3, now.minus(90, ChronoUnit.DAYS), now.minus(40, ChronoUnit.DAYS))
        val cards = Dashboard.enrich(
            listOf(group(10, 1), group(20, 2), group(30, 3), group(40, 99)),
            listOf(running, justEnded, longEnded),
            now,
        )
        val byGroup = cards.associateBy { it.group.id }
        assertFalse(byGroup.getValue(10).ended)
        assertTrue(byGroup.getValue(20).ended); assertTrue(byGroup.getValue(20).recentlyEnded)
        assertTrue(byGroup.getValue(30).ended); assertFalse(byGroup.getValue(30).recentlyEnded)
        assertTrue("missing tournament => ended", byGroup.getValue(40).ended)
    }

    @Test
    fun `running tab keeps recently-ended - ended tab excludes it`() {
        val cards = Dashboard.enrich(
            listOf(group(10, 1), group(20, 2), group(30, 3)),
            listOf(
                tournament(1, now.minusSeconds(1000), now.plusSeconds(1000)),
                tournament(2, now.minus(40, ChronoUnit.DAYS), now.minus(3, ChronoUnit.DAYS)),
                tournament(3, now.minus(90, ChronoUnit.DAYS), now.minus(40, ChronoUnit.DAYS)),
            ),
            now,
        )
        assertEquals(setOf(10, 20), Dashboard.runningTab(cards).map { it.group.id }.toSet())
        assertEquals(setOf(30), Dashboard.endedTab(cards).map { it.group.id }.toSet())
    }

    @Test
    fun `countdown target is the soonest future kickoff across running groups`() {
        val cards = Dashboard.enrich(
            listOf(group(10, 1), group(20, 2)),
            listOf(
                tournament(1, now.plus(5, ChronoUnit.DAYS), now.plus(20, ChronoUnit.DAYS)),
                tournament(2, now.plus(2, ChronoUnit.DAYS), now.plus(20, ChronoUnit.DAYS)),
            ),
            now,
        )
        val target = Dashboard.countdownTarget(cards, now)
        assertEquals("T2", target?.tournamentName)
    }

    @Test
    fun `countdown is null once every running tournament has kicked off`() {
        val cards = Dashboard.enrich(
            listOf(group(10, 1)),
            listOf(tournament(1, now.minusSeconds(60), now.plus(5, ChronoUnit.DAYS))),
            now,
        )
        assertNull(Dashboard.countdownTarget(cards, now))
    }

    @Test
    fun `grouped layout buckets shared tournaments but keeps custom-header groups single`() {
        val t1 = tournament(1, now.plusSeconds(10), now.plus(9, ChronoUnit.DAYS))
        val cards = Dashboard.enrich(
            listOf(group(10, 1), group(20, 1), group(30, 1, header = "https://img/cover.png")),
            listOf(t1),
            now,
        )
        val grouped = Dashboard.layout(cards, grouped = true)
        // groups 10+20 bucket together; 30 has a custom header → stays single.
        assertEquals(1, grouped.count { it is DashboardItem.Bucket })
        val bucket = grouped.filterIsInstance<DashboardItem.Bucket>().first()
        assertEquals(setOf(10, 20), bucket.cards.map { it.group.id }.toSet())
        assertTrue(grouped.filterIsInstance<DashboardItem.Single>().any { it.card.group.id == 30 })
    }

    @Test
    fun `list layout is one card per group`() {
        val cards = Dashboard.enrich(
            listOf(group(10, 1), group(20, 1)),
            listOf(tournament(1, now, now.plus(2, ChronoUnit.DAYS))),
            now,
        )
        assertEquals(2, Dashboard.layout(cards, grouped = false).size)
    }

    @Test
    fun `default leaderboard tournament is the latest start among running`() {
        val all = listOf(
            tournament(1, now.minus(10, ChronoUnit.DAYS), now.plus(2, ChronoUnit.DAYS)),
            tournament(2, now.minus(3, ChronoUnit.DAYS), now.plus(2, ChronoUnit.DAYS)),
        )
        assertEquals(2, Dashboard.defaultLeaderboardTournament(all, all)?.id)
    }
}
