import Foundation

/// Pure schedule logic ported from web `Pools.vue` + `Game.vue` (test-pinned there):
/// flatten pools' games, sort by kickoff, group by calendar day, title the groups, and
/// format per-game kickoff labels with date-fns-compatible English strings.
nonisolated enum TournamentSchedule {
    /// A game tagged with the pool it came from (the web keeps `poolName` on the
    /// flattened game — it must survive into tap payloads).
    struct Entry: Identifiable, Hashable {
        let game: Game
        let poolName: String
        var id: Int { game.id }
    }

    /// One calendar day of the schedule.
    struct Day: Identifiable, Hashable {
        let id: String
        let date: Date
        let title: String
        var poolNames: [String]
        var entries: [Entry]
        var isNextUpcoming: Bool

        /// Web header rule: pool names joined " & " in order of first appearance after
        /// sorting; if the joined string contains "Group" show the day title only,
        /// else "<pools> - <day title>".
        var headerText: String {
            let name = poolNames.joined(separator: " & ")
            return name.contains("Group") ? title : "\(name) - \(title)"
        }
    }

    /// Flatten + stable sort by `start_date`, group by local calendar day, and flag the
    /// first day containing a game with `start_date >= now` as next upcoming (a day
    /// whose first game already started can still be next upcoming via a later game).
    static func days(
        pools: [PoolGames],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Day] {
        let flattened = pools.flatMap { pool in
            pool.games.map { Entry(game: $0, poolName: pool.pool.name) }
        }
        // Stable sort (web `toSorted` is stable; Swift's sort is not guaranteed to be).
        let sorted = flattened.enumerated()
            .sorted { a, b in
                if a.element.game.startDate != b.element.game.startDate {
                    return a.element.game.startDate < b.element.game.startDate
                }
                return a.offset < b.offset
            }
            .map(\.element)

        var days: [Day] = []
        var nextUpcomingKey: String?
        for entry in sorted {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.game.startDate)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            if let index = days.firstIndex(where: { $0.id == key }) {
                if !days[index].poolNames.contains(entry.poolName) {
                    days[index].poolNames.append(entry.poolName)
                }
                days[index].entries.append(entry)
            } else {
                days.append(Day(
                    id: key,
                    date: entry.game.startDate,
                    title: dayTitle(for: entry.game.startDate, now: now, calendar: calendar),
                    poolNames: [entry.poolName],
                    entries: [entry],
                    isNextUpcoming: false
                ))
            }
            if nextUpcomingKey == nil, entry.game.startDate >= now {
                nextUpcomingKey = key
            }
        }
        if let key = nextUpcomingKey, let index = days.firstIndex(where: { $0.id == key }) {
            days[index].isNextUpcoming = true
        }
        return days
    }

    /// "Today" / "Tomorrow" / date-fns `formatDistance(startOfDay(date), startOfDay(now),
    /// addSuffix: true)` — "2 days ago", "in 3 days".
    static func dayTitle(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        let startOfNow = calendar.startOfDay(for: now)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfNow),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let startOfDate = calendar.startOfDay(for: date)
        let dayDiff = calendar.dateComponents([.day], from: startOfNow, to: startOfDate).day ?? 0
        return relativeDays(dayDiff)
    }

    /// Web `Game.vue` kickoff label (pinned):
    /// 1. finished → "Finished"
    /// 2. today AND truncated whole hours < 4 (incl. negative) → strict relative with
    ///    ceiling rounding + clock time — "in 2 hours, 14:00" / "3 hours ago, 09:00"
    /// 3. today → "Today, EEE HH:mm"
    /// 4. tomorrow → "Tomorrow, EEE HH:mm"
    /// 5. else → "EEE dd MMM HH:mm"
    static func dateLabel(for game: Game, now: Date = Date(), calendar: Calendar = .current) -> String {
        if game.isFinished { return "Finished" }
        let start = game.startDate
        let formatter = makeFormatter(calendar)
        if calendar.isDate(start, inSameDayAs: now) {
            if GameClock.wholeHoursUntilStart(of: game, at: now) < 4 {
                formatter.dateFormat = "HH:mm"
                return "\(strictRelative(to: start, from: now)), \(formatter.string(from: start))"
            }
            formatter.dateFormat = "EEE HH:mm"
            return "Today, \(formatter.string(from: start))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(start, inSameDayAs: tomorrow) {
            formatter.dateFormat = "EEE HH:mm"
            return "Tomorrow, \(formatter.string(from: start))"
        }
        formatter.dateFormat = "EEE dd MMM HH:mm"
        return formatter.string(from: start)
    }

    /// date-fns `formatDistanceStrict(roundingMethod: ceil, addSuffix: true)` for the
    /// seconds/minutes/hours range — the unit is chosen from the raw distance, then the
    /// value is ceiling-divided. (Only used for same-day distances, so hours suffice.)
    static func strictRelative(to target: Date, from now: Date) -> String {
        let interval = target.timeIntervalSince(now)
        let absSeconds = abs(interval)
        let value: Int
        let unit: String
        if absSeconds < 60 {
            value = Int(absSeconds.rounded(.up))
            unit = "second"
        } else if absSeconds < 3600 {
            value = Int((absSeconds / 60).rounded(.up))
            unit = "minute"
        } else {
            value = Int((absSeconds / 3600).rounded(.up))
            unit = "hour"
        }
        let phrase = "\(value) \(unit)\(value == 1 ? "" : "s")"
        return interval > 0 ? "in \(phrase)" : "\(phrase) ago"
    }

    /// Tournament header dates, web `format(date, 'MMM dd HH:mm')` joined with " - ".
    /// A missing end date renders the start alone (the web would crash — improved here).
    static func tournamentDates(start: Date, end: Date?, calendar: Calendar = .current) -> String {
        let formatter = makeFormatter(calendar)
        formatter.dateFormat = "MMM dd HH:mm"
        let startText = formatter.string(from: start)
        guard let end else { return startText }
        return "\(startText) - \(formatter.string(from: end))"
    }

    /// date-fns `formatDistance` day-scale phrases (suffix included).
    private static func relativeDays(_ diff: Int) -> String {
        let magnitude = abs(diff)
        let phrase: String
        switch magnitude {
        case 0:
            phrase = "0 days" // unreachable — "Today" is handled before
        case 1:
            phrase = "1 day"
        case ..<30:
            phrase = "\(magnitude) days"
        case ..<45:
            phrase = "about 1 month"
        case ..<60:
            phrase = "about 2 months"
        default:
            phrase = "\(Int((Double(magnitude) / 30).rounded())) months"
        }
        return diff >= 0 ? "in \(phrase)" : "\(phrase) ago"
    }

    /// Fixed-English formatter so labels match the web's date-fns output exactly.
    private static func makeFormatter(_ calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
