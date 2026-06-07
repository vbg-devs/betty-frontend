import Foundation

/// Dense tie ranking (pinned by web tests): walk the score-descending list; `place`
/// increments only when the score is strictly lower than the previous one. Ties share a
/// place and the next distinct score gets place + 1 — i.e. 10, 10, 8 -> places 1, 1, 2
/// (dense, NOT competition ranking 1, 1, 3).
nonisolated enum DenseRanking {
    struct Ranked<T>: Identifiable where T: Identifiable {
        let place: Int
        let item: T
        var id: T.ID { item.id }
    }

    static func rank<T: Identifiable>(_ items: [T], score: (T) -> Double) -> [Ranked<T>] {
        let sorted = items.sorted { score($0) > score($1) }
        var result: [Ranked<T>] = []
        result.reserveCapacity(sorted.count)
        var place = 0
        var previousScore: Double?
        for item in sorted {
            let s = score(item)
            if previousScore == nil || s < previousScore! { place += 1 }
            previousScore = s
            result.append(Ranked(place: place, item: item))
        }
        return result
    }
}

/// Largest-remainder bet-distribution percentages — always sums to exactly 100.
/// Remainder ties break in fixed order home, away, tie (pinned: 1/1/1 -> 34/33/33).
nonisolated enum LargestRemainder {
    static func percentages(home: Int, away: Int, tie: Int) -> (home: Int, tie: Int, away: Int) {
        let total = home + away + tie
        guard total > 0 else { return (0, 0, 0) }
        // Priority order for remainder distribution: home(0), away(1), tie(2).
        let counts = [home, away, tie]
        let exact = counts.map { Double($0) * 100 / Double(total) }
        var floors = exact.map { Int($0.rounded(.down)) }
        var remaining = 100 - floors.reduce(0, +)
        let order = [0, 1, 2].sorted { a, b in
            let ra = exact[a] - Double(floors[a])
            let rb = exact[b] - Double(floors[b])
            if ra != rb { return ra > rb }
            return a < b
        }
        for index in order where remaining > 0 {
            floors[index] += 1
            remaining -= 1
        }
        return (home: floors[0], tie: floors[2], away: floors[1])
    }
}

/// Shared bet-ownership helpers (used by schedule, urgent-games banner, game cards,
/// bet sheet). A logged-out user (`userID == nil`) never owns a bet.
nonisolated enum BetOwnership {
    static func hasBet(in bets: [Bet], gameID: Int, userID: String?) -> Bool {
        firstOwnBet(in: bets, gameID: gameID, userID: userID) != nil
    }

    /// First matching own bet in array order (the pinned "first wins" rule).
    static func firstOwnBet(in bets: [Bet], gameID: Int, userID: String?) -> Bet? {
        guard let userID else { return nil }
        return bets.first { $0.gameID == gameID && $0.userID == userID }
    }

    /// Count of ALL users' bets on the game (the bet-count chip).
    static func betCount(in bets: [Bet], gameID: Int) -> Int {
        bets.count { $0.gameID == gameID }
    }
}

/// Kickoff clock helpers with the web's exact semantics.
nonisolated enum GameClock {
    /// `differenceInHours` — TRUNCATED whole hours until kickoff (negative when past).
    /// Urgency borders: urgent when 0 < h <= 24, danger when 0 < h <= 12.
    static func wholeHoursUntilStart(of game: Game, at now: Date = Date()) -> Int {
        Int(game.startDate.timeIntervalSince(now) / 3600)
    }

    /// Fractional hours until kickoff — the NeedAction urgency rule uses
    /// `0 < hoursLeft < 24` strictly (exactly 24.0 h is NOT urgent; 30 min away is).
    static func fractionalHoursUntilStart(of game: Game, at now: Date = Date()) -> Double {
        game.startDate.timeIntervalSince(now) / 3600
    }
}
