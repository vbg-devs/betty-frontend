package social.betty.features.browse

import social.betty.core.model.PublicGroupItem

/** One rendered card on the Browse screen. */
sealed class BrowseCard {
    abstract val cardKey: String

    data class Single(val group: PublicGroupItem) : BrowseCard() {
        override val cardKey = "g-${group.id}"
    }

    data class TournamentBucket(
        val tournamentId: Int,
        val tournamentName: String,
        val tournamentImageUrl: String?,
        val groups: List<PublicGroupItem>,
    ) : BrowseCard() {
        override val cardKey = "t-$tournamentId"
    }
}

/**
 * Mirrors the web `visibleCards` bucketing logic (browse.vue) and BrowseGrouping.swift:
 *
 * - List mode → every item becomes a Single card.
 * - Grouped mode → items with a custom headerImageUrl stay Single (emitted first, in item
 *   order); the rest are bucketed by tournamentId in first-appearance order; a bucket of
 *   one collapses back to a Single.
 */
object BrowseGrouping {
    fun cards(items: List<PublicGroupItem>, grouped: Boolean): List<BrowseCard> {
        if (!grouped) return items.map { BrowseCard.Single(it) }

        val cards = mutableListOf<BrowseCard>()
        val bucketOrder = mutableListOf<Int>()
        val buckets = mutableMapOf<Int, MutableList<PublicGroupItem>>()

        for (item in items) {
            if (item.headerImageUrl != null) {
                cards += BrowseCard.Single(item)
                continue
            }
            if (!buckets.containsKey(item.tournamentId)) {
                bucketOrder += item.tournamentId
            }
            buckets.getOrPut(item.tournamentId) { mutableListOf() } += item
        }

        for (tId in bucketOrder) {
            val bucket = buckets[tId] ?: continue
            val first = bucket.firstOrNull() ?: continue
            if (bucket.size == 1) {
                cards += BrowseCard.Single(first)
            } else {
                cards += BrowseCard.TournamentBucket(
                    tournamentId = tId,
                    tournamentName = first.tournamentName ?: "",
                    tournamentImageUrl = first.tournamentImageUrl,
                    groups = bucket,
                )
            }
        }

        return cards
    }
}
