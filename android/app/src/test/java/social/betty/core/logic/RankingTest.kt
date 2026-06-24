package social.betty.core.logic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.model.GroupMember

class RankingTest {

    private fun member(uid: String, score: Int) = GroupMember(userId = uid, score = score)

    @Test
    fun `dense ranking shares ties and skips to next distinct place`() {
        val members = listOf(member("a", 8), member("b", 10), member("c", 10))
        val ranked = Ranking.rank(members)
        // sorted desc: b(10)=1, c(10)=1, a(8)=2
        assertEquals(listOf("b", "c", "a"), ranked.map { it.userId })
        assertEquals(listOf(1, 1, 2), ranked.map { it.place })
    }

    @Test
    fun `placement uses string uid compare and pads to two digits`() {
        val ranked = Ranking.rank(listOf(member("a", 5), member("me", 9), member("c", 5)))
        assertEquals(1, Ranking.placementOf(ranked, "me"))
        assertEquals("01", Ranking.placementLabel(Ranking.placementOf(ranked, "me")))
        assertEquals("–", Ranking.placementLabel(Ranking.placementOf(ranked, "ghost")))
    }

    @Test
    fun `champions and youWon cover all members tied at place one`() {
        val ranked = Ranking.rank(listOf(member("a", 10), member("b", 10), member("c", 4)))
        assertEquals(setOf("a", "b"), Ranking.champions(ranked).map { it.userId }.toSet())
        assertTrue(Ranking.youWon(ranked, "b"))
        assertFalse(Ranking.youWon(ranked, "c"))
    }

    @Test
    fun `podium buckets places one to three`() {
        val ranked = Ranking.rank(
            listOf(member("a", 9), member("b", 7), member("c", 7), member("d", 5), member("e", 1)),
        )
        val podium = Ranking.podium(ranked)
        assertEquals(setOf("a"), podium.getValue(1).map { it.userId }.toSet())
        assertEquals(setOf("b", "c"), podium.getValue(2).map { it.userId }.toSet())
        assertEquals(setOf("d"), podium.getValue(3).map { it.userId }.toSet())
        assertFalse(podium.containsKey(4))
    }

    @Test
    fun `normalized ranking falls back to zero when missing`() {
        val members = listOf(
            GroupMember(userId = "a", normalizedScore = 3.0),
            GroupMember(userId = "b", normalizedScore = null),
            GroupMember(userId = "c", normalizedScore = 5.0),
        )
        val ranked = Ranking.rankByNormalized(members)
        assertEquals(listOf("c", "a", "b"), ranked.map { it.userId })
    }
}
