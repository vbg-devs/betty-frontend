package social.betty.core.logic

import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Pool
import social.betty.core.model.Tournament
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Per-game annotations for a schedule row (data-layer.md §6.4 step 6). */
data class GameAnnotation(
    val game: Game,
    val poolName: String,
    val hasBet: Boolean,
    val betCount: Int,
    val myHome: Int?,
    val myAway: Int?,
    val myBoosted: Boolean = false,
)

data class DayGroup(
    val dayKey: LocalDate,
    val title: String,
    val poolNames: String,
    val games: List<GameAnnotation>,
    val isNextUpcoming: Boolean,
)

/** Live window after kickoff (Game.vue: 150 minutes). */
private val LIVE_WINDOW: Duration = Duration.ofMinutes(150)

object GameSchedule {
    private val hmFormat = DateTimeFormatter.ofPattern("HH:mm", Locale.ENGLISH)
    private val dowHm = DateTimeFormatter.ofPattern("EEE HH:mm", Locale.ENGLISH)
    private val fullFormat = DateTimeFormatter.ofPattern("EEE dd MMM HH:mm", Locale.ENGLISH)

    /** `status == 1` is finished; live = not finished AND now ∈ (start, start+150min). */
    fun isLive(game: Game, now: Instant = Instant.now()): Boolean {
        val start = game.startDate ?: return false
        return !game.isFinished && now.isAfter(start) && now.isBefore(start.plus(LIVE_WINDOW))
    }

    /** Kickoff label (data-layer.md §6.5), localized to [zone]. */
    fun kickoffLabel(start: Instant?, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): String {
        if (start == null) return ""
        val startLocal = start.atZone(zone)
        val nowLocal = now.atZone(zone)
        val dayDelta = Duration.between(nowLocal.toLocalDate().atStartOfDay(zone), startLocal.toLocalDate().atStartOfDay(zone)).toDays()
        val minutesAway = Duration.between(now, start).toMinutes()
        return when {
            dayDelta == 0L && minutesAway in 0..239 -> "${relativeMinutes(minutesAway)}, ${startLocal.format(hmFormat)}"
            dayDelta == 0L -> "Today, ${startLocal.format(dowHm)}"
            dayDelta == 1L -> "Tomorrow, ${startLocal.format(hmFormat)}"
            else -> startLocal.format(fullFormat)
        }
    }

    private fun relativeMinutes(minutes: Long): String = when {
        minutes <= 1 -> "in 1 minute"
        minutes < 60 -> "in $minutes minutes"
        else -> {
            val h = minutes / 60
            "in $h ${if (h == 1L) "hour" else "hours"}"
        }
    }

    /**
     * Day-grouped schedule (data-layer.md §6.4): flatten games (tagged with pool name), sort
     * by start asc, bucket by calendar day, title Today/Tomorrow/relative, pool names joined
     * with " & ", and flag the first group containing a future game as `isNextUpcoming`.
     */
    fun group(
        detail: Tournament,
        groupBets: List<Bet>,
        uid: String?,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<DayGroup> {
        val poolsById: Map<Int, Pool> = detail.pools.associateBy { it.id }
        val betsByGame: Map<Int, List<Bet>> = groupBets.groupBy { it.gameId }

        val annotated = detail.games
            .sortedBy { it.startDate ?: Instant.EPOCH }
            .map { game ->
                val gameBets = betsByGame[game.id].orEmpty()
                val mine = gameBets.firstOrNull { it.userId == uid }
                GameAnnotation(
                    game = game,
                    poolName = poolsById[game.poolId]?.name.orEmpty(),
                    hasBet = mine != null,
                    betCount = gameBets.size,
                    myHome = mine?.homeTeamScore,
                    myAway = mine?.awayTeamScore,
                    myBoosted = mine?.boosted == true,
                )
            }

        val byDay = annotated.groupBy { it.game.startDate?.atZone(zone)?.toLocalDate() ?: LocalDate.MIN }
        val sortedDays = byDay.keys.sortedBy { it }
        var nextFlagged = false
        return sortedDays.map { day ->
            val games = byDay.getValue(day)
            val isNext = !nextFlagged && games.any { (it.game.startDate ?: Instant.EPOCH) >= now }
            if (isNext) nextFlagged = true
            DayGroup(
                dayKey = day,
                title = dayTitle(day, LocalDate.now(nowClock(now, zone))),
                poolNames = games.map { it.poolName }.filter { it.isNotBlank() }.distinct().joinToString(" & "),
                games = games,
                isNextUpcoming = isNext,
            )
        }
    }

    private fun nowClock(now: Instant, zone: ZoneId): java.time.Clock =
        java.time.Clock.fixed(now, zone)

    private fun dayTitle(day: LocalDate, today: LocalDate): String {
        val delta = java.time.temporal.ChronoUnit.DAYS.between(today, day)
        return when {
            delta == 0L -> "Today"
            delta == 1L -> "Tomorrow"
            delta == -1L -> "Yesterday"
            delta > 1L -> "in $delta days"
            else -> "${-delta} days ago"
        }
    }
}
