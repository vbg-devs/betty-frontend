import Foundation
import Testing
@testable import Betty

private let now = GroupDetailFixtures.date("2026-06-05T12:00:00Z")
private let future = GroupDetailFixtures.date("2026-06-05T15:00:00Z")
private let past = GroupDetailFixtures.date("2026-06-05T11:00:00Z")

@Suite("Bet sheet logic (BetModal.vue pins)")
struct GroupBetLogicTests {
    @Test func showScoresAfterKickoffOrWithSneakPeek() {
        #expect(!GroupBetLogic.showScores(start: future, peek: false, now: now))
        #expect(GroupBetLogic.showScores(start: future, peek: true, now: now))
        #expect(GroupBetLogic.showScores(start: past, peek: false, now: now))
    }

    @Test func lockInputAfterKickoff() {
        #expect(!GroupBetLogic.lockInput(start: future, now: now))
        #expect(GroupBetLogic.lockInput(start: past, now: now))
    }

    @Test func canSaveRequiresBothFieldsAndUnstartedGame() {
        #expect(GroupBetLogic.canSave(start: future, home: "2", away: "1", now: now))
        #expect(!GroupBetLogic.canSave(start: future, home: "", away: "1", now: now))
        #expect(!GroupBetLogic.canSave(start: future, home: "2", away: "", now: now))
        // Started game disables regardless of input.
        #expect(!GroupBetLogic.canSave(start: past, home: "2", away: "1", now: now))
    }

    @Test func orderedBetsByPointsDescendingNilAsZeroStable() {
        let bets = [
            GroupDetailFixtures.bet(id: 1, userID: "a", userPoints: nil),
            GroupDetailFixtures.bet(id: 2, userID: "b", userPoints: 3),
            GroupDetailFixtures.bet(id: 3, userID: "c", userPoints: 0),
            GroupDetailFixtures.bet(id: 4, userID: "d", userPoints: 1),
        ]
        let ordered = GroupBetLogic.orderedBets(bets)
        // nil counts as 0 and keeps original order relative to the explicit 0.
        #expect(ordered.map(\.id) == [2, 4, 1, 3])
    }

    @Test func submitRoutePins() {
        let existing = GroupDetailFixtures.bet(id: 42, userID: "me")
        // Existing bet + box UNCHECKED -> single-group PUT.
        #expect(GroupBetLogic.submitRoute(existing: existing, placeInAllGroups: false) == .update(betID: 42))
        // Existing bet + box CHECKED -> universal re-POST, never PUT.
        #expect(GroupBetLogic.submitRoute(existing: existing, placeInAllGroups: true) == .place(isUniversal: true))
        // New bet -> POST either way, is_universal mirrors the checkbox.
        #expect(GroupBetLogic.submitRoute(existing: nil, placeInAllGroups: true) == .place(isUniversal: true))
        #expect(GroupBetLogic.submitRoute(existing: nil, placeInAllGroups: false) == .place(isUniversal: false))
    }

    @Test func distributionPins() {
        func bet(_ home: Int, _ away: Int) -> Bet {
            GroupDetailFixtures.bet(homeScore: home, awayScore: away)
        }
        // 2 home / 1 away / 1 tie -> 50/25/25.
        var split = GroupBetLogic.distribution([bet(2, 0), bet(3, 1), bet(0, 1), bet(1, 1)])
        #expect(split == (home: 50, tie: 25, away: 25))
        // 1/1/1 -> 34/33/33 (remainder tie-break order home, away, tie).
        split = GroupBetLogic.distribution([bet(1, 0), bet(0, 1), bet(2, 2)])
        #expect(split == (home: 34, tie: 33, away: 33))
        // 3 home / 2 away / 2 tie of 7 -> home 43, away 29, tie 28.
        split = GroupBetLogic.distribution([
            bet(1, 0), bet(2, 0), bet(3, 0),
            bet(0, 1), bet(0, 2),
            bet(0, 0), bet(1, 1),
        ])
        #expect(split == (home: 43, tie: 28, away: 29))
        // Zero bets -> 0/0/0.
        split = GroupBetLogic.distribution([])
        #expect(split == (home: 0, tie: 0, away: 0))
    }
}

@Suite("Bet history row logic (UserBetListItem.vue pins)")
struct GroupBetRowLogicTests {
    @Test func showScoreRules() {
        let pending = GroupDetailFixtures.bet(userID: "a")
        // Hidden pre-kickoff without peek.
        #expect(!GroupBetRowLogic.showScore(bet: pending, gameStart: future, peek: false, now: now))
        // Peek reveals.
        #expect(GroupBetRowLogic.showScore(bet: pending, gameStart: future, peek: true, now: now))
        // Kickoff reveals.
        #expect(GroupBetRowLogic.showScore(bet: pending, gameStart: past, peek: false, now: now))
        // Processed reveals even with a missing game.
        let processed = GroupDetailFixtures.bet(userID: "a", userPoints: 3, processed: true)
        #expect(GroupBetRowLogic.showScore(bet: processed, gameStart: nil, peek: false, now: now))
        // Missing game start degrades to hidden.
        #expect(!GroupBetRowLogic.showScore(bet: pending, gameStart: nil, peek: false, now: now))
    }

    @Test func pendingUnlessVisibleAndProcessed() {
        let unprocessed = GroupDetailFixtures.bet(userID: "a", userPoints: nil)
        #expect(GroupBetRowLogic.result(bet: unprocessed, showScore: true, exactResultPoints: 5) == .pending)
        let processed = GroupDetailFixtures.bet(userID: "a", userPoints: 3, processed: true)
        #expect(GroupBetRowLogic.result(bet: processed, showScore: false, exactResultPoints: 5) == .pending)
    }

    @Test func exactUsesGroupConfigWhenKnown() {
        // Pin: with correct=3 / exact=5, 3 points is a WIN (not exact), 5 is EXACT.
        let win = GroupDetailFixtures.bet(userID: "a", userPoints: 3, processed: true)
        #expect(GroupBetRowLogic.result(bet: win, showScore: true, exactResultPoints: 5) == .win)
        let exact = GroupDetailFixtures.bet(userID: "a", userPoints: 5, processed: true)
        #expect(GroupBetRowLogic.result(bet: exact, showScore: true, exactResultPoints: 5) == .exact)
    }

    @Test func legacyHeuristicWhenGroupConfigUnknown() {
        let three = GroupDetailFixtures.bet(userID: "a", userPoints: 3, processed: true)
        #expect(GroupBetRowLogic.result(bet: three, showScore: true, exactResultPoints: nil) == .exact)
        let four = GroupDetailFixtures.bet(userID: "a", userPoints: 4, processed: true)
        #expect(GroupBetRowLogic.result(bet: four, showScore: true, exactResultPoints: nil) == .exact)
        let one = GroupDetailFixtures.bet(userID: "a", userPoints: 1, processed: true)
        #expect(GroupBetRowLogic.result(bet: one, showScore: true, exactResultPoints: nil) == .win)
    }

    @Test func zeroPointsIsMissEvenWhenItMatchesExactConfig() {
        let zero = GroupDetailFixtures.bet(userID: "a", userPoints: 0, processed: true)
        #expect(GroupBetRowLogic.result(bet: zero, showScore: true, exactResultPoints: 0) == .miss)
        #expect(GroupBetRowLogic.result(bet: zero, showScore: true, exactResultPoints: 5) == .miss)
    }
}

@Suite("Member bet history (UserHistory.vue pins)")
struct GroupUserHistoryLogicTests {
    // game 2 starts first (2026-06-05), then game 1 (2026-06-07). The two `now` values
    // bracket those: `beforeAll` is pre-kickoff for both, `afterAll` is post-kickoff for both.
    private let games = [
        GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-07T12:00:00Z")),
        GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-05T12:00:00Z")),
    ]
    private let beforeAll = GroupDetailFixtures.date("2026-06-05T11:00:00Z")
    private let afterAll = GroupDetailFixtures.date("2026-06-10T12:00:00Z")

    @Test func filtersJoinsAndSortsByKickoff() {
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 1, userPoints: 3, processed: true),
            GroupDetailFixtures.bet(id: 11, userID: "other", gameID: 1, userPoints: 5, processed: true),
            GroupDetailFixtures.bet(id: 12, userID: "me", gameID: 2, userPoints: nil),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: beforeAll)
        // Other members' bets excluded; sorted ascending by game start (game 2 first).
        #expect(entries.compactMap { $0.bet?.id } == [12, 10])
        #expect(entries.map(\.game.id) == [2, 1])
    }

    @Test func orphanBetsAreSilentlyDroppedAndCountTowardNothing() {
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 1, userPoints: 3, processed: true),
            GroupDetailFixtures.bet(id: 13, userID: "me", gameID: 999, userPoints: 7, processed: true),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: beforeAll)
        #expect(entries.compactMap { $0.bet?.id } == [10])
        #expect(GroupUserHistoryLogic.totalPoints(entries) == 3)
    }

    @Test func totalPointsTreatsNilAsZero() {
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 1, userPoints: 3, processed: true),
            GroupDetailFixtures.bet(id: 12, userID: "me", gameID: 2, userPoints: nil),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: beforeAll)
        #expect(GroupUserHistoryLogic.totalPoints(entries) == 3)
    }

    @Test func emptyWhenMemberHasNoBetsAndNoGamesStarted() {
        let entries = GroupUserHistoryLogic.entries(bets: [], userID: "me", games: games, now: beforeAll)
        #expect(entries.isEmpty)
        #expect(GroupUserHistoryLogic.totalPoints(entries) == 0)
        #expect(GroupUserHistoryLogic.betsCount(entries) == 0)
    }

    @Test func startedGamesWithoutABetRenderAsSkippedRows() {
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 2, userPoints: 3, processed: true),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: afterAll)
        // game 2 (bet) then game 1 (skipped) by kickoff order.
        #expect(entries.map(\.game.id) == [2, 1])
        #expect(entries[0].bet?.id == 10)
        #expect(entries[1].bet == nil)
        // betsCount and totalPoints only see actual bets.
        #expect(GroupUserHistoryLogic.betsCount(entries) == 1)
        #expect(GroupUserHistoryLogic.totalPoints(entries) == 3)
    }

    @Test func futureGamesWithoutABetAreOmitted() {
        // beforeAll: both games are in the future. With zero bets, nothing renders —
        // we don't leak who hasn't placed bets yet (the hidden-score / pre-kickoff pin).
        let entries = GroupUserHistoryLogic.entries(bets: [], userID: "me", games: games, now: beforeAll)
        #expect(entries.isEmpty)
    }

    @Test func futureGameWithABetIsStillIncluded() {
        // beforeAll: game 1 future + bet on it. game 2 future + no bet. Only the bet row appears.
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 1, userPoints: nil),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: beforeAll)
        #expect(entries.map(\.game.id) == [1])
        #expect(entries[0].bet?.id == 10)
    }

    @Test func interleavesBetsAndSkippedRowsInChronologicalOrder() {
        // afterAll: both games started. Bet on the earlier one, skipped the later.
        let bets = [
            GroupDetailFixtures.bet(id: 10, userID: "me", gameID: 2, userPoints: 1, processed: true),
        ]
        let entries = GroupUserHistoryLogic.entries(bets: bets, userID: "me", games: games, now: afterAll)
        #expect(entries.map(\.game.id) == [2, 1])
        #expect(entries[0].bet?.id == 10)
        #expect(entries[1].bet == nil)
    }
}
