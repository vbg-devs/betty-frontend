import Foundation

/// Running / Ended dashboard tabs (web `selectedTab`).
nonisolated enum HomeTab: Hashable {
    case running
    case ended
}

/// A `GroupPlacement` joined client-side with its tournament and classified per the web
/// rules: *ended* when the tournament is missing OR `end_date < now`; *recentlyEnded*
/// when ended less than 28 days ago (still shown under Running with a JUST ENDED badge).
nonisolated struct HomeGroupItem: Identifiable, Hashable {
    let placement: GroupPlacement
    let tournament: Tournament?
    let ended: Bool
    let recentlyEnded: Bool

    var id: Int { placement.id }
    var isPublic: Bool { placement.publicAt != nil }

    /// Empty-string header URLs are falsy on the web — treat them as missing.
    var headerImageURL: String? {
        guard let url = placement.headerImageURL, !url.isEmpty else { return nil }
        return url
    }
}

/// Hero headline cases (web pins the exact copy).
nonisolated enum HomeHeadline: Equatable {
    case groups(count: Int)
    case noneRunning
    case noneEnded
    case empty

    /// Plain-colored first portion.
    var leadText: String {
        switch self {
        case .groups(let count): "\(count) "
        case .noneRunning: "NO RUNNING"
        case .noneEnded: "NO ENDED"
        case .empty: "NO GROUPS"
        }
    }

    /// Green portion — first-line suffix for `.groups`, second line otherwise.
    var accentText: String {
        switch self {
        case .groups(let count): count == 1 ? "GROUP." : "GROUPS."
        case .noneRunning, .noneEnded: "GROUPS."
        case .empty: "YET."
        }
    }

    /// Orange second line — only the `.groups` case has one.
    var trailingText: String? {
        if case .groups = self { return "ONE CHAMPION." }
        return nil
    }
}

/// The earliest strictly-future tournament kickoff across running groups.
nonisolated struct HomeKickoff: Equatable {
    let tournament: Tournament
    let startDate: Date
}

/// DD:HH:MM:SS countdown parts (floored total seconds, clamped at zero).
nonisolated struct HomeCountdown: Equatable {
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int

    static func until(_ target: Date, now: Date) -> HomeCountdown {
        let total = Int(max(0, target.timeIntervalSince(now)).rounded(.down))
        return HomeCountdown(
            days: total / 86_400,
            hours: (total % 86_400) / 3_600,
            minutes: (total % 3_600) / 60,
            seconds: total % 60
        )
    }

    /// Web `padStart(2, '0')` — 3+ digit values keep all digits.
    static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// One dashboard card — `stack` buckets groups sharing a tournament in grouped mode.
nonisolated enum HomeCard: Identifiable, Hashable {
    case single(HomeGroupItem)
    case stack(tournament: Tournament, items: [HomeGroupItem], ended: Bool, recentlyEnded: Bool)

    var id: String {
        switch self {
        case .single(let item): "g-\(item.id)"
        case .stack(let tournament, _, _, _): "t-\(tournament.id)"
        }
    }
}

/// Per-group input for the need-action banner: the group's tournament games plus the
/// group's bet matrix (used for "is this game un-bet for me?").
nonisolated struct HomeNeedActionSource: Hashable {
    let groupID: Int
    let groupName: String
    let games: [Game]
    let bets: [Bet]
}

/// A game surfaced by the need-action banner with the group context to bet in.
nonisolated struct HomeNeedActionEntry: Identifiable, Hashable {
    let game: Game
    let groupID: Int
    /// First own bet across sources (today's-games rows show the placed score).
    let ownBet: Bet?

    var id: Int { game.id }
    var hasOwnBet: Bool { ownBet != nil }
}

/// NeedAction display selection: urgent games win, else today's games, else nothing.
nonisolated enum HomeNeedActionDisplay: Equatable {
    case urgent([HomeNeedActionEntry])
    case today([HomeNeedActionEntry])
    case hidden
}

/// Pure dashboard logic ported from `app/pages/dashboard/index.vue` and
/// `app/components/NeedAction.vue` (edge cases pinned by the web tests).
nonisolated enum HomeDashboardLogic {
    /// Recently-ended groups stay in Running for four weeks.
    static let recentlyEndedWindow: TimeInterval = 60 * 60 * 24 * 28

    // MARK: group classification

    static func classify(
        _ placements: [GroupPlacement],
        tournament: (Int) -> Tournament?,
        now: Date
    ) -> [HomeGroupItem] {
        placements.map { placement in
            let joined = tournament(placement.tournamentID)
            let endDate = joined?.endDate
            let ended = joined == nil || (endDate != nil && endDate! < now)
            let recentlyEnded = ended
                && endDate != nil
                && now.timeIntervalSince(endDate!) < recentlyEndedWindow
            return HomeGroupItem(
                placement: placement,
                tournament: joined,
                ended: ended,
                recentlyEnded: recentlyEnded
            )
        }
    }

    static func running(_ items: [HomeGroupItem]) -> [HomeGroupItem] {
        items.filter { !$0.ended || $0.recentlyEnded }
    }

    static func ended(_ items: [HomeGroupItem]) -> [HomeGroupItem] {
        items.filter { $0.ended && !$0.recentlyEnded }
    }

    static func headline(visibleCount: Int, totalCount: Int, tab: HomeTab) -> HomeHeadline {
        if visibleCount > 0 { return .groups(count: visibleCount) }
        if totalCount > 0 { return tab == .running ? .noneRunning : .noneEnded }
        return .empty
    }

    // MARK: first-kickoff countdown

    /// Earliest `tournament.start_date` STRICTLY in the future across running groups
    /// (already-ended tournaments never reach here — they aren't running). Ties keep the
    /// first group in list order.
    static func nextKickoff(across running: [HomeGroupItem], now: Date) -> HomeKickoff? {
        var best: HomeKickoff?
        for item in running {
            guard let tournament = item.tournament else { continue }
            let start = tournament.startDate
            guard start > now else { continue }
            if best == nil || start < best!.startDate {
                best = HomeKickoff(tournament: tournament, startDate: start)
            }
        }
        return best
    }

    // MARK: grouped cards

    /// List mode: one single card per group, in order. Grouped mode mirrors the web:
    /// groups with a header image or no joined tournament stay single (inline, in
    /// order); the rest bucket by tournament in first-seen order and are appended after
    /// the singles — 1-group buckets degrade back to single cards.
    static func cards(visible: [HomeGroupItem], grouped: Bool) -> [HomeCard] {
        guard grouped else { return visible.map(HomeCard.single) }

        var singles: [HomeCard] = []
        var bucketOrder: [Int] = []
        var buckets: [Int: [HomeGroupItem]] = [:]

        for item in visible {
            guard item.headerImageURL == nil, let tournament = item.tournament else {
                singles.append(.single(item))
                continue
            }
            if buckets[tournament.id] == nil { bucketOrder.append(tournament.id) }
            buckets[tournament.id, default: []].append(item)
        }

        var cards = singles
        for tournamentID in bucketOrder {
            let items = buckets[tournamentID]!
            if items.count == 1 {
                cards.append(.single(items[0]))
            } else {
                let first = items[0]
                cards.append(.stack(
                    tournament: first.tournament!,
                    items: items,
                    ended: first.ended,
                    recentlyEnded: first.recentlyEnded
                ))
            }
        }
        return cards
    }

    // MARK: need action

    /// Urgent = not finished (`status != 1`), un-bet by me in that group, and
    /// `0 < fractional hours < 24` STRICT (exactly 24.0h is not urgent; 30 minutes away
    /// is). Globally sorted by start date, deduped by game (the first group where the
    /// game is un-bet wins), capped at 3.
    static func urgentEntries(
        sources: [HomeNeedActionSource],
        userID: String?,
        now: Date
    ) -> [HomeNeedActionEntry] {
        var seen = Set<Int>()
        var entries: [HomeNeedActionEntry] = []
        for (game, source) in mergedGamesSortedByStart(sources) {
            guard entries.count < 3 else { break }
            guard !game.isFinished else { continue }
            let hoursLeft = GameClock.fractionalHoursUntilStart(of: game, at: now)
            guard hoursLeft > 0, hoursLeft < 24 else { continue }
            guard !BetOwnership.hasBet(in: source.bets, gameID: game.id, userID: userID) else { continue }
            guard seen.insert(game.id).inserted else { continue }
            entries.append(HomeNeedActionEntry(game: game, groupID: source.groupID, ownBet: nil))
        }
        return entries
    }

    /// Any game starting on the same calendar day as `now` — including already started,
    /// finished, and already-bet games. Deduped by game (first source wins), sorted by
    /// start date.
    static func todaysEntries(
        sources: [HomeNeedActionSource],
        userID: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> [HomeNeedActionEntry] {
        var seen = Set<Int>()
        var entries: [HomeNeedActionEntry] = []
        for (game, source) in mergedGamesSortedByStart(sources) {
            guard calendar.isDate(game.startDate, inSameDayAs: now) else { continue }
            guard seen.insert(game.id).inserted else { continue }
            let ownBet = firstOwnBet(across: sources, gameID: game.id, userID: userID)
            entries.append(HomeNeedActionEntry(game: game, groupID: source.groupID, ownBet: ownBet))
        }
        return entries
    }

    static func needActionDisplay(
        sources: [HomeNeedActionSource],
        userID: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> HomeNeedActionDisplay {
        let urgent = urgentEntries(sources: sources, userID: userID, now: now)
        if !urgent.isEmpty { return .urgent(urgent) }
        let today = todaysEntries(sources: sources, userID: userID, now: now, calendar: calendar)
        if !today.isEmpty { return .today(today) }
        return .hidden
    }

    // MARK: private

    /// Flattens every source's games and stable-sorts by start date — equal kickoffs
    /// keep source order, so duplicate games surface their first source first.
    private static func mergedGamesSortedByStart(
        _ sources: [HomeNeedActionSource]
    ) -> [(game: Game, source: HomeNeedActionSource)] {
        let flat = sources.flatMap { source in source.games.map { (game: $0, source: source) } }
        return flat.enumerated()
            .sorted { a, b in
                if a.element.game.startDate != b.element.game.startDate {
                    return a.element.game.startDate < b.element.game.startDate
                }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    private static func firstOwnBet(
        across sources: [HomeNeedActionSource],
        gameID: Int,
        userID: String?
    ) -> Bet? {
        for source in sources {
            if let bet = BetOwnership.firstOwnBet(in: source.bets, gameID: gameID, userID: userID) {
                return bet
            }
        }
        return nil
    }
}
