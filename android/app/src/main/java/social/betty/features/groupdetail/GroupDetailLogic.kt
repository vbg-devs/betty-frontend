package social.betty.features.groupdetail

import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Group
import social.betty.core.model.GroupMember
import social.betty.core.model.MessageReaction
import java.time.Instant
import java.time.ZoneId
import kotlin.math.roundToInt

/**
 * Pure, derived helpers for the GroupDetail feature, ported 1:1 from the iOS
 * `GroupDetailLogic.swift` (and the web group page). Kept feature-local; the cross-platform
 * `Ranking` / `GameSchedule` live in `core/logic`.
 */

/** First own bet on a game (array order = "first wins"); a logged-out user owns none. */
fun firstOwnBet(bets: List<Bet>, gameId: Int, userId: String?): Bet? {
    if (userId == null) return null
    return bets.firstOrNull { it.gameId == gameId && it.userId == userId }
}

/** All-users bet count on a game (the bet-count chip). */
fun betCount(bets: List<Bet>, gameId: Int): Int = bets.count { it.gameId == gameId }

object GroupGameCardLogic {
    /**
     * Awarded points (below the placed-bet chip): finished games only, from the FIRST own
     * bet; null when unfinished, no own bet, the bet is unevaluated, or logged out.
     */
    fun awardedPoints(game: Game, bets: List<Bet>, userId: String?): Int? {
        if (!game.isFinished) return null
        return firstOwnBet(bets, game.id, userId)?.userPoints
    }

    /**
     * Whether the awarded-points cell should render a rocket: own bet on a finished game,
     * it's `boosted`, AND it scored > 0 points (spec §2.5 suppression rule).
     */
    fun awardedBoosted(game: Game, bets: List<Bet>, userId: String?): Boolean {
        if (!game.isFinished) return false
        val bet = firstOwnBet(bets, game.id, userId) ?: return false
        return bet.boosted && (bet.userPoints ?: 0) > 0
    }
}

/** NeedAction strip selection (web `NeedAction.vue`), scoped to a single group source. */
object NeedAction {
    sealed interface Display {
        data class Urgent(val games: List<Game>) : Display
        data class Today(val games: List<Game>) : Display
        data object Hidden : Display
    }

    /** Fractional hours until kickoff (negative when past). */
    private fun fractionalHoursUntilStart(game: Game, now: Instant): Double {
        val start = game.startDate ?: return Double.NEGATIVE_INFINITY
        return (start.epochSecond - now.epochSecond) / 3600.0
    }

    /**
     * Urgent: not finished, un-bet by me, `0 < fractional hours < 24` STRICT; sorted by
     * kickoff, capped at 3. Else today's games (any game on `now`'s calendar day). Else hidden.
     */
    fun display(
        games: List<Game>,
        bets: List<Bet>,
        userId: String?,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Display {
        val sorted = games.sortedBy { it.startDate ?: Instant.EPOCH }
        val urgent = sorted.filter { game ->
            if (game.isFinished) return@filter false
            val hours = fractionalHoursUntilStart(game, now)
            if (hours <= 0.0 || hours >= 24.0) return@filter false
            firstOwnBet(bets, game.id, userId) == null
        }.take(3)
        if (urgent.isNotEmpty()) return Display.Urgent(urgent)

        val today = now.atZone(zone).toLocalDate()
        val todays = sorted.filter { game ->
            game.startDate?.atZone(zone)?.toLocalDate() == today
        }
        if (todays.isNotEmpty()) return Display.Today(todays)
        return Display.Hidden
    }
}

object GroupBetLogic {
    /** Opponents' scores show after kickoff, or any time the group allows sneak peek. */
    fun showScores(start: Instant?, peek: Boolean, now: Instant): Boolean {
        if (peek) return true
        val s = start ?: return false
        return now.isAfter(s)
    }

    fun lockInput(start: Instant?, now: Instant): Boolean {
        val s = start ?: return false
        return now.isAfter(s)
    }

    fun canSave(start: Instant?, home: String, away: String, now: Instant): Boolean {
        if (lockInput(start, now)) return false
        if (home.isEmpty() || away.isEmpty()) return false
        return true
    }

    /** Placed-bets ordering: `user_points` desc (null = 0), stable. */
    fun orderedBets(bets: List<Bet>): List<Bet> =
        bets.withIndex().sortedWith(
            compareByDescending<IndexedValue<Bet>> { it.value.userPoints ?: 0 }
                .thenBy { it.index },
        ).map { it.value }

    sealed interface SubmitRoute {
        data class Update(val betId: Int) : SubmitRoute
        data class Place(val isUniversal: Boolean) : SubmitRoute
    }

    /**
     * CRITICAL pin: only an existing bet with the all-groups box UNCHECKED routes through
     * PUT /bet/:id; every other case re-POSTs (universal edits upsert across all groups).
     */
    fun submitRoute(existing: Bet?, placeInAllGroups: Boolean): SubmitRoute =
        if (existing != null && !placeInAllGroups) {
            SubmitRoute.Update(existing.id)
        } else {
            SubmitRoute.Place(placeInAllGroups)
        }

    /** Home/tie/away distribution percentages (largest remainder, sums to exactly 100). */
    fun distribution(bets: List<Bet>): Triple<Int, Int, Int> {
        val home = bets.count { it.homeTeamScore > it.awayTeamScore }
        val away = bets.count { it.awayTeamScore > it.homeTeamScore }
        val tie = bets.count { it.homeTeamScore == it.awayTeamScore }
        return LargestRemainder.percentages(home = home, away = away, tie = tie)
    }
}

/** Largest-remainder percentages — sums to exactly 100; ties break home, away, tie. */
object LargestRemainder {
    /** Returns (home, tie, away). */
    fun percentages(home: Int, away: Int, tie: Int): Triple<Int, Int, Int> {
        val total = home + away + tie
        if (total <= 0) return Triple(0, 0, 0)
        val counts = listOf(home, away, tie) // priority: home(0), away(1), tie(2)
        val exact = counts.map { it * 100.0 / total }
        val floors = exact.map { it.toInt() }.toMutableList()
        var remaining = 100 - floors.sum()
        val order = listOf(0, 1, 2).sortedWith(
            compareByDescending<Int> { exact[it] - floors[it] }.thenBy { it },
        )
        for (index in order) {
            if (remaining <= 0) break
            floors[index] += 1
            remaining -= 1
        }
        return Triple(floors[0], floors[2], floors[1])
    }
}

/** Bet-history row result + visibility (web `UserBetListItem.vue`). */
object GroupBetRowLogic {
    enum class Result { PENDING, EXACT, WIN, MISS }

    /** `showScore = peek || processed || (start known && now > start)`. */
    fun showScore(bet: Bet, gameStart: Instant?, peek: Boolean, now: Instant): Boolean {
        if (peek) return true
        if (bet.isProcessed) return true
        if (gameStart != null && now.isAfter(gameStart)) return true
        return false
    }

    fun result(bet: Bet, showScore: Boolean, exactResultPoints: Int?): Result {
        if (!showScore || !bet.isProcessed) return Result.PENDING
        val points = bet.userPoints ?: 0
        val isExact = if (exactResultPoints != null) {
            points == exactResultPoints
        } else {
            points == 3 || points == 4
        }
        if (isExact && points > 0) return Result.EXACT
        if (points > 0) return Result.WIN
        return Result.MISS
    }
}

/**
 * Member bet-history row (web `UserHistory.vue`). A null `bet` is a "NO BET" row for a
 * game the member skipped — only included once the game has started (so we don't leak
 * who hasn't placed bets yet on upcoming games).
 */
data class UserHistoryEntry(val bet: Bet?, val game: Game)

object GroupUserHistoryLogic {
    /**
     * One row per game: bet-row if the member bet on it, skipped-row ("NO BET") if the
     * game has already started. Future games the member hasn't bet on are omitted
     * (the hidden-score / pre-kickoff pin — don't leak un-placed bets). Sorted ascending
     * by kickoff, stable.
     */
    fun entries(
        bets: List<Bet>,
        userId: String,
        games: List<Game>,
        now: Instant = Instant.now(),
    ): List<UserHistoryEntry> {
        val betByGameId = bets.asSequence()
            .filter { it.userId == userId }
            .associateBy { it.gameId }

        val rows = games.mapNotNull { game ->
            betByGameId[game.id]?.let { return@mapNotNull UserHistoryEntry(it, game) }
            val start = game.startDate
            if (start != null && now.isAfter(start)) UserHistoryEntry(null, game) else null
        }

        return rows.withIndex()
            .sortedWith(
                compareBy<IndexedValue<UserHistoryEntry>> {
                    it.value.game.startDate ?: Instant.EPOCH
                }.thenBy { it.index },
            )
            .map { it.value }
    }

    /** "<N> BETS" — only actual bets, not skipped rows. */
    fun betsCount(entries: List<UserHistoryEntry>): Int = entries.count { it.bet != null }

    /** Σ user_points over the bets only (null/skipped count as 0). */
    fun totalPoints(entries: List<UserHistoryEntry>): Int =
        entries.sumOf { it.bet?.userPoints ?: 0 }
}

object GroupStandings {
    /** Completion %: `round(complete / all * 100)`, 0 when nothing is complete. */
    fun completionPercentage(completeGames: Int, allGames: Int): Int {
        if (completeGames <= 0 || allGames <= 0) return 0
        return (completeGames.toDouble() / allGames.toDouble() * 100).roundToInt()
    }
}

/** Chat reaction grouping/toggle rules (web `toggleReaction`). */
data class ReactionGroup(val emojiId: String, val count: Int, val reactedByMe: Boolean)

object ReactionLogic {
    /** Groups reactions by emoji in first-seen order, with count + reacted-by-me flag. */
    fun grouped(reactions: List<MessageReaction>, currentUserId: String?): List<ReactionGroup> {
        val order = mutableListOf<String>()
        val counts = linkedMapOf<String, Int>()
        val mine = mutableSetOf<String>()
        for (reaction in reactions) {
            if (reaction.emojiId !in counts) order += reaction.emojiId
            counts[reaction.emojiId] = (counts[reaction.emojiId] ?: 0) + 1
            if (currentUserId != null && reaction.userId == currentUserId) mine += reaction.emojiId
        }
        return order.map { ReactionGroup(it, counts.getValue(it), it in mine) }
    }

    sealed interface ToggleAction {
        data class Set(val emojiId: String) : ToggleAction
        data object Remove : ToggleAction
    }

    /** Tap my current emoji → remove; any other → replace (one per user). null = logged out. */
    fun toggleAction(emojiId: String, reactions: List<MessageReaction>, currentUserId: String?): ToggleAction? {
        if (currentUserId == null) return null
        val mine = reactions.firstOrNull { it.userId == currentUserId }
        if (mine != null && mine.emojiId == emojiId) return ToggleAction.Remove
        return ToggleAction.Set(emojiId)
    }
}

/** Author name resolution (web `nickname || name || 'Unknown'`). */
fun chatAuthorName(member: GroupMember?): String {
    if (member == null) return "Unknown"
    member.nickname?.takeIf { it.isNotEmpty() }?.let { return it }
    member.name?.takeIf { it.isNotEmpty() }?.let { return it }
    return "Unknown"
}

/** Relative "x ago" timestamp; "just now" under a minute. */
fun relativeTime(instant: Instant?, now: Instant = Instant.now()): String {
    if (instant == null) return ""
    val seconds = now.epochSecond - instant.epochSecond
    if (seconds < 60) return "just now"
    val minutes = seconds / 60
    if (minutes < 60) return if (minutes == 1L) "1 minute ago" else "$minutes minutes ago"
    val hours = minutes / 60
    if (hours < 24) return if (hours == 1L) "1 hour ago" else "$hours hours ago"
    val days = hours / 24
    if (days < 7) return if (days == 1L) "1 day ago" else "$days days ago"
    val weeks = days / 7
    if (weeks < 5) return if (weeks == 1L) "1 week ago" else "$weeks weeks ago"
    val months = days / 30
    if (months < 12) return if (months == 1L) "1 month ago" else "$months months ago"
    val years = days / 365
    return if (years == 1L) "1 year ago" else "$years years ago"
}

/**
 * Day-group header text (web `Pools.vue`): pool names joined " & "; when the joined name
 * contains "Group" show the day title only, else "<PoolNames> - <DayTitle>".
 */
fun dayGroupHeaderText(poolNames: String, dayTitle: String): String {
    if (poolNames.isBlank()) return dayTitle
    if (poolNames.contains("Group")) return dayTitle
    return "$poolNames - $dayTitle"
}

/** Group author check (`access_level == 0`). */
fun Group.isAuthor(userId: String?): Boolean =
    userId != null && members.firstOrNull { it.userId == userId }?.accessLevel == 0

/** Display name: nickname || name || "Player". */
fun GroupMember.displayName(): String =
    nickname?.takeIf { it.isNotEmpty() }
        ?: name?.takeIf { it.isNotEmpty() }
        ?: "Player"
