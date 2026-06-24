package social.betty.core.logic

import social.betty.core.model.GroupMember

data class RankedMember(val member: GroupMember, val place: Int) {
    val userId: String get() = member.userId
}

/**
 * Dense ranking with ties (data-layer.md §6.1): sort by score desc; `place` starts at 0 and
 * increments only when the current score is *strictly less* than the previous (10,10,8 →
 * 1,1,2). [score] selects group `score` or tournament `normalized_score`.
 */
object Ranking {
    fun rank(
        members: List<GroupMember>,
        score: (GroupMember) -> Double = { it.score.toDouble() },
    ): List<RankedMember> {
        val sorted = members.sortedByDescending(score)
        var place = 0
        var prev: Double? = null
        return sorted.map { member ->
            val s = score(member)
            if (prev == null || s < prev!!) place += 1
            prev = s
            RankedMember(member, place)
        }
    }

    fun rankByNormalized(members: List<GroupMember>): List<RankedMember> =
        rank(members) { it.normalizedScore ?: 0.0 }

    /** The place of [uid] (string compare), or null when absent. */
    fun placementOf(ranked: List<RankedMember>, uid: String?): Int? =
        uid?.let { id -> ranked.firstOrNull { it.userId == id }?.place }

    /** Zero-padded display ("01", "12") or "–" when absent. */
    fun placementLabel(place: Int?): String = place?.let { "%02d".format(it) } ?: "–"

    /** All members tied at place 1. */
    fun champions(ranked: List<RankedMember>): List<GroupMember> =
        ranked.filter { it.place == 1 }.map { it.member }

    fun youWon(ranked: List<RankedMember>, uid: String?): Boolean =
        uid != null && champions(ranked).any { it.userId == uid }

    /** Places 1–3 bucketed by place (a slot may hold multiple tied members). */
    fun podium(ranked: List<RankedMember>): Map<Int, List<GroupMember>> =
        ranked.filter { it.place <= 3 }.groupBy({ it.place }, { it.member })
}
