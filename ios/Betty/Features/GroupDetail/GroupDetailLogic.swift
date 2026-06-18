import Foundation

// Pure, test-pinned ports of the web group page's derived logic
// (`app/pages/dashboard/groups/[id]/index.vue`, `Pools.vue`, `Game.vue`, `BetModal.vue`,
// `UserBetListItem.vue`, `UserHistory.vue`).

// MARK: - Game date label (Game.vue `startDate`)

nonisolated enum GroupGameDateLabel {
    /// Pinned label rules:
    /// 1. finished → "Finished"
    /// 2. today AND truncated whole hours until start < 4 (includes negative, i.e. games
    ///    started earlier today past the live window) → strict relative with ceiling
    ///    rounding + clock time: "in 2 hours, 14:00" / "3 hours ago, 09:00"
    /// 3. today, >= 4h away → "Today, Fri 18:00"
    /// 4. tomorrow → "Tomorrow, Sat 15:00"
    /// 5. else → "Mon 08 Jun 12:00"
    static func text(for game: Game, at now: Date = Date(), calendar: Calendar = .current) -> String {
        if game.isFinished { return "Finished" }
        let start = game.startDate
        if calendar.isDate(start, inSameDayAs: now) {
            if GameClock.wholeHoursUntilStart(of: game, at: now) < 4 {
                return "\(strictRelative(to: start, from: now)), \(format("HH:mm", start, calendar))"
            }
            return "Today, \(format("EEE HH:mm", start, calendar))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(start, inSameDayAs: tomorrow) {
            return "Tomorrow, \(format("EEE HH:mm", start, calendar))"
        }
        return format("EEE dd MMM HH:mm", start, calendar)
    }

    /// date-fns `formatDistanceStrict(roundingMethod: ceil, addSuffix: true)` for the
    /// seconds/minutes/hours range this label can hit (same-day distances only).
    static func strictRelative(to date: Date, from now: Date) -> String {
        let interval = date.timeIntervalSince(now)
        let isFuture = interval > 0
        let absSeconds = abs(interval)
        let phrase: String
        if absSeconds < 60 {
            let seconds = max(1, Int(absSeconds.rounded(.up)))
            phrase = seconds == 1 ? "1 second" : "\(seconds) seconds"
        } else {
            let minutes = Int((absSeconds / 60).rounded(.up))
            if minutes < 60 {
                phrase = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            } else {
                let hours = Int((absSeconds / 3600).rounded(.up))
                phrase = hours == 1 ? "1 hour" : "\(hours) hours"
            }
        }
        return isFuture ? "in \(phrase)" : "\(phrase) ago"
    }

    private static func format(_ pattern: String, _ date: Date, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

// MARK: - Game card derived state (Game.vue)

nonisolated enum GroupGameCardLogic {
    /// Awarded points (below the placed-bet chip): only for finished games, from the FIRST
    /// own bet in array order; hidden (nil) when unfinished, no own bet, unevaluated bet,
    /// or logged out.
    static func awardedPoints(game: Game, bets: [Bet], userID: String?) -> Int? {
        guard game.isFinished else { return nil }
        return BetOwnership.firstOwnBet(in: bets, gameID: game.id, userID: userID)?.userPoints
    }

    /// True iff the user's own bet on this finished game has `boosted == true`. The
    /// rocket-suppression check (`points > 0`) is left to the view (where the count is
    /// already in hand) so this helper doesn't have to re-derive it.
    static func awardedBoosted(game: Game, bets: [Bet], userID: String?) -> Bool {
        guard game.isFinished else { return false }
        return BetOwnership.firstOwnBet(in: bets, gameID: game.id, userID: userID)?.boosted ?? false
    }
}

// MARK: - Day-grouped schedule (Pools.vue `gameGroups`)

nonisolated struct GroupScheduleGame: Identifiable, Hashable {
    let game: Game
    let poolName: String
    var id: Int { game.id }
}

nonisolated struct GroupGameDayGroup: Identifiable, Hashable {
    /// Calendar-day key ("y-m-d").
    let key: String
    let date: Date
    /// "Today" / "Tomorrow" / "in 3 days" / "2 days ago".
    let title: String
    /// Distinct pool names in order of first appearance after the global sort.
    let poolNames: [String]
    let isNextUpcoming: Bool
    let games: [GroupScheduleGame]

    var id: String { key }

    /// Web pin: pool names joined " & "; when the joined string contains "Group" the
    /// header shows the day title only, otherwise "<PoolNames> - <DayTitle>".
    var headerText: String {
        let name = poolNames.joined(separator: " & ")
        if name.contains("Group") { return title }
        return "\(name) - \(title)"
    }
}

nonisolated enum GroupGameDaySchedule {
    static func build(pools: [PoolGames], now: Date = Date(), calendar: Calendar = .current) -> [GroupGameDayGroup] {
        // Flatten with pool-name tags, stable-sort by start date ascending.
        var flattened: [GroupScheduleGame] = []
        for pool in pools {
            flattened.append(contentsOf: pool.games.map { GroupScheduleGame(game: $0, poolName: pool.pool.name) })
        }
        let sorted = flattened.enumerated().sorted { a, b in
            if a.element.game.startDate != b.element.game.startDate {
                return a.element.game.startDate < b.element.game.startDate
            }
            return a.offset < b.offset
        }.map(\.element)

        struct Working {
            let key: String
            let date: Date
            var poolNames: [String]
            var games: [GroupScheduleGame]
            var isNextUpcoming = false
        }

        var groups: [Working] = []
        var nextUpcomingKey: String?
        for entry in sorted {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.game.startDate)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            if let index = groups.firstIndex(where: { $0.key == key }) {
                if !groups[index].poolNames.contains(entry.poolName) {
                    groups[index].poolNames.append(entry.poolName)
                }
                groups[index].games.append(entry)
            } else {
                groups.append(Working(key: key, date: entry.game.startDate, poolNames: [entry.poolName], games: [entry]))
            }
            // First game starting at/after now flags ITS day group — pinned: if today's
            // first game already started but a later one today hasn't, today is still next.
            if nextUpcomingKey == nil, entry.game.startDate >= now {
                nextUpcomingKey = key
            }
        }

        return groups.map { working in
            GroupGameDayGroup(
                key: working.key,
                date: working.date,
                title: dayTitle(for: working.date, now: now, calendar: calendar),
                poolNames: working.poolNames,
                isNextUpcoming: working.key == nextUpcomingKey,
                games: working.games
            )
        }
    }

    static func nextUpcomingKey(in groups: [GroupGameDayGroup]) -> String? {
        groups.first(where: \.isNextUpcoming)?.key
    }

    /// date-fns `formatDistance(startOfDay(date), startOfDay(now), addSuffix: true)`
    /// for the day-distance range ("Today"/"Tomorrow" are special-cased first).
    static func dayTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if days > 0 {
            return days == 1 ? "in 1 day" : "in \(days) days"
        }
        let past = abs(days)
        return past == 1 ? "1 day ago" : "\(past) days ago"
    }
}

// MARK: - Standings (group page rankedMembers / podium / champion)

nonisolated struct GroupPodiumSlot: Identifiable, Hashable {
    let place: Int
    let members: [Member]
    var id: Int { place }
}

nonisolated enum GroupStandings {
    /// Dense tie ranking on `score` (shared pinned helper).
    static func ranked(_ members: [Member]) -> [DenseRanking.Ranked<Member>] {
        DenseRanking.rank(members) { Double($0.score) }
    }

    /// Final podium: places 1–3 bucketed by place; a slot can hold multiple tied members.
    static func podium(_ ranked: [DenseRanking.Ranked<Member>]) -> [GroupPodiumSlot] {
        var slots: [GroupPodiumSlot] = []
        for entry in ranked where entry.place <= 3 {
            if let index = slots.firstIndex(where: { $0.place == entry.place }) {
                slots[index] = GroupPodiumSlot(place: entry.place, members: slots[index].members + [entry.item])
            } else {
                slots.append(GroupPodiumSlot(place: entry.place, members: [entry.item]))
            }
        }
        return slots
    }

    /// All members at place 1.
    static func champions(_ ranked: [DenseRanking.Ranked<Member>]) -> [Member] {
        ranked.filter { $0.place == 1 }.map(\.item)
    }

    static func yourPlace(_ ranked: [DenseRanking.Ranked<Member>], userID: String?) -> Int? {
        guard let userID else { return nil }
        return ranked.first { $0.item.userID == userID }?.place
    }

    /// Zero-padded place ("01") or an en dash when absent.
    static func placeDisplay(_ place: Int?) -> String {
        guard let place else { return "–" }
        return String(format: "%02d", place)
    }

    /// Completion %: `round(complete / all * 100)`, 0 when nothing is complete.
    static func completionPercentage(completeGames: Int, allGames: Int) -> Int {
        guard completeGames > 0, allGames > 0 else { return 0 }
        return Int((Double(completeGames) / Double(allGames) * 100).rounded())
    }
}

// MARK: - Bet sheet (BetModal.vue)

nonisolated enum GroupBetLogic {
    /// Sneak-peek rule: opponents' scores show after kickoff, or any time when the
    /// group allows sneak peek.
    static func showScores(start: Date, peek: Bool, now: Date = Date()) -> Bool {
        now > start || peek
    }

    static func lockInput(start: Date, now: Date = Date()) -> Bool {
        now > start
    }

    /// Save enabled only pre-kickoff with BOTH fields non-empty.
    static func canSave(start: Date, home: String, away: String, now: Date = Date()) -> Bool {
        if lockInput(start: start, now: now) { return false }
        if home.isEmpty || away.isEmpty { return false }
        return true
    }

    /// Placed-bets ordering: `user_points` descending (nil counts as 0), stable.
    static func orderedBets(_ bets: [Bet]) -> [Bet] {
        bets.enumerated().sorted { a, b in
            let pa = a.element.userPoints ?? 0
            let pb = b.element.userPoints ?? 0
            if pa != pb { return pa > pb }
            return a.offset < b.offset
        }.map(\.element)
    }

    enum SubmitRoute: Equatable {
        case update(betID: Int)
        case place(isUniversal: Bool)
    }

    /// CRITICAL regression pin: only an existing bet with the all-groups box UNCHECKED
    /// routes through PUT /bet/:id; every other case re-POSTs (universal edits must
    /// upsert across all groups of the tournament).
    static func submitRoute(existing: Bet?, placeInAllGroups: Bool) -> SubmitRoute {
        if let existing, !placeInAllGroups {
            return .update(betID: existing.id)
        }
        return .place(isUniversal: placeInAllGroups)
    }

    /// Home/tie/away distribution percentages (largest remainder, sums to exactly 100).
    static func distribution(_ bets: [Bet]) -> (home: Int, tie: Int, away: Int) {
        LargestRemainder.percentages(
            home: bets.count { $0.homeTeamScore > $0.awayTeamScore },
            away: bets.count { $0.awayTeamScore > $0.homeTeamScore },
            tie: bets.count { $0.homeTeamScore == $0.awayTeamScore }
        )
    }
}

// MARK: - Bet history row (UserBetListItem.vue)

nonisolated enum GroupBetRowLogic {
    enum Result: Equatable { case pending, exact, win, miss }

    /// `showScore = peek || processed || (game start known && now > start)`.
    static func showScore(bet: Bet, gameStart: Date?, peek: Bool, now: Date = Date()) -> Bool {
        if peek { return true }
        if bet.isProcessed { return true }
        if let gameStart, now > gameStart { return true }
        return false
    }

    /// Result styling: pending unless score is visible AND processed. Exact compares
    /// against the group's `exact_result_points` when known, else the legacy 3-or-4
    /// heuristic. Exact requires points > 0; any other positive is a win; 0 is a miss.
    static func result(bet: Bet, showScore: Bool, exactResultPoints: Int?) -> Result {
        guard showScore, bet.isProcessed else { return .pending }
        let points = bet.userPoints ?? 0
        let isExact: Bool
        if let exactResultPoints {
            isExact = points == exactResultPoints
        } else {
            isExact = points == 3 || points == 4
        }
        if isExact && points > 0 { return .exact }
        if points > 0 { return .win }
        return .miss
    }
}

// MARK: - Cover upload error copy (group page header-image flow)

nonisolated enum GroupCoverPolicy {
    static let authorOnlyMessage = "Only the group author can change the cover."
    static let unavailableMessage = "Uploads are unavailable right now. Please try again later."

    /// Cover-upload failure copy: 401/403 author gate, 503 storage outage, then the
    /// shared image-upload mapping (413 size / 415 type / generic).
    static func errorMessage(status: Int?) -> String {
        switch status {
        case 401, 403: authorOnlyMessage
        case 503: unavailableMessage
        default: ProfileImagePolicy.uploadErrorMessage(status: status)
        }
    }
}

// MARK: - Member bet history (UserHistory.vue)

/// One row in a member's bet-history sheet. `bet == nil` is a "NO BET" row for a game
/// the member skipped — only included once the game has started (so we don't leak who
/// hasn't placed bets yet on upcoming games).
nonisolated struct GroupUserHistoryEntry: Identifiable, Hashable {
    let bet: Bet?
    let game: Game
    var id: Int { game.id }
}

nonisolated enum GroupUserHistoryLogic {
    /// Build one row per game: bet-row if the member bet on it, skipped-row ("NO BET")
    /// if the game has already started. Future games the member hasn't bet on are
    /// omitted (the hidden-score / pre-kickoff pattern — don't leak un-placed bets).
    /// Sorted ascending by kickoff, stable.
    static func entries(bets: [Bet], userID: String, games: [Game], now: Date = Date()) -> [GroupUserHistoryEntry] {
        var betByGameID: [Int: Bet] = [:]
        for bet in bets where bet.userID == userID {
            betByGameID[bet.gameID] = bet
        }

        let rows: [GroupUserHistoryEntry] = games.compactMap { game in
            if let bet = betByGameID[game.id] {
                return GroupUserHistoryEntry(bet: bet, game: game)
            }
            if now > game.startDate {
                return GroupUserHistoryEntry(bet: nil, game: game)
            }
            return nil
        }

        return rows.enumerated().sorted { a, b in
            if a.element.game.startDate != b.element.game.startDate {
                return a.element.game.startDate < b.element.game.startDate
            }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// "<N> BETS" — only actual bets, not skipped rows.
    static func betsCount(_ entries: [GroupUserHistoryEntry]) -> Int {
        entries.lazy.filter { $0.bet != nil }.count
    }

    /// Σ user_points over the bets only (nil/skipped count as 0).
    static func totalPoints(_ entries: [GroupUserHistoryEntry]) -> Int {
        entries.reduce(0) { $0 + ($1.bet?.userPoints ?? 0) }
    }
}
