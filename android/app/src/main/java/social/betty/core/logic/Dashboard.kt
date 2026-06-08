package social.betty.core.logic

import social.betty.core.model.Group
import social.betty.core.model.Tournament
import java.time.Duration
import java.time.Instant

/** A group enriched with its tournament + ended/recently-ended state (data-layer.md §6.6). */
data class DashboardGroup(
    val group: Group,
    val tournament: Tournament?,
    val ended: Boolean,
    val recentlyEnded: Boolean,
)

sealed interface DashboardItem {
    data class Single(val card: DashboardGroup) : DashboardItem
    data class Bucket(val tournament: Tournament, val cards: List<DashboardGroup>) : DashboardItem
}

data class CountdownTarget(val tournamentName: String, val startDate: Instant)

object Dashboard {
    private val RECENT_WINDOW: Duration = Duration.ofDays(28)

    fun enrich(groups: List<Group>, tournaments: List<Tournament>, now: Instant = Instant.now()): List<DashboardGroup> {
        val byId = tournaments.associateBy { it.id }
        return groups.map { group ->
            val tournament = byId[group.tournamentId]
            val end = tournament?.endDate
            val ended = tournament == null || (end != null && end.isBefore(now))
            val recentlyEnded = end != null && ended &&
                end.isAfter(now.minus(RECENT_WINDOW)) && end.isBefore(now)
            DashboardGroup(group, tournament, ended, recentlyEnded)
        }
    }

    /** Running tab: not ended, or ended within the last 28 days ("JUST ENDED"). */
    fun runningTab(cards: List<DashboardGroup>): List<DashboardGroup> =
        cards.filter { !it.ended || it.recentlyEnded }

    fun endedTab(cards: List<DashboardGroup>): List<DashboardGroup> =
        cards.filter { it.ended && !it.recentlyEnded }

    /**
     * Countdown hero target: among running-tab groups' tournaments, the soonest `start_date`
     * strictly in the future. Null once every running tournament has kicked off.
     */
    fun countdownTarget(cards: List<DashboardGroup>, now: Instant = Instant.now()): CountdownTarget? =
        runningTab(cards)
            .mapNotNull { it.tournament }
            .distinctBy { it.id }
            .mapNotNull { t -> t.startDate?.let { CountdownTarget(t.name, it) } }
            .filter { it.startDate.isAfter(now) }
            .minByOrNull { it.startDate }

    /**
     * Card layout (data-layer.md §6.6): grouping OFF → one card per group. ON → bucket by
     * tournament id, except groups with a custom header image or no tournament (always single);
     * singleton buckets collapse back to single cards.
     */
    fun layout(cards: List<DashboardGroup>, grouped: Boolean): List<DashboardItem> {
        if (!grouped) return cards.map { DashboardItem.Single(it) }

        val singles = mutableListOf<DashboardGroup>()
        val bucketable = mutableListOf<DashboardGroup>()
        for (card in cards) {
            if (card.tournament == null || !card.group.headerImageUrl.isNullOrBlank()) {
                singles += card
            } else {
                bucketable += card
            }
        }
        val buckets = bucketable.groupBy { it.group.tournamentId }
        val items = mutableListOf<DashboardItem>()
        // Preserve input order by walking cards once and emitting each bucket/single at first sight.
        val emitted = HashSet<Int>()
        for (card in cards) {
            if (card in singles) {
                items += DashboardItem.Single(card)
            } else {
                val tid = card.group.tournamentId
                if (emitted.add(tid)) {
                    val group = buckets.getValue(tid)
                    items += if (group.size == 1) {
                        DashboardItem.Single(group.first())
                    } else {
                        DashboardItem.Bucket(group.first().tournament!!, group)
                    }
                }
            }
        }
        return items
    }

    /** Default global-leaderboard tournament (data-layer.md §6.7): latest start_date. */
    fun defaultLeaderboardTournament(
        running: List<Tournament>,
        all: List<Tournament>,
    ): Tournament? {
        val pool = running.ifEmpty { all }
        return pool.maxByOrNull { it.startDate ?: Instant.EPOCH }
    }
}
