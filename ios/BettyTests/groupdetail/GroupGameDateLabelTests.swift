import Foundation
import Testing
@testable import Betty

// 2026-06-05 is a Friday.
private let now = GroupDetailFixtures.date("2026-06-05T12:00:00Z")
private let calendar = GroupDetailFixtures.utcCalendar

private func label(start: Date, status: Int? = nil) -> String {
    GroupGameDateLabel.text(
        for: GroupDetailFixtures.game(start: start, status: status),
        at: now,
        calendar: calendar
    )
}

@Suite("Game date label (Game.vue startDate pins)")
struct GroupGameDateLabelTests {
    @Test func finishedGameSaysFinished() {
        #expect(label(start: now.addingTimeInterval(-3600), status: 1) == "Finished")
        // Finished wins even for future-dated games.
        #expect(label(start: now.addingTimeInterval(7200), status: 1) == "Finished")
    }

    @Test func todayUnderFourHoursIsStrictRelativeWithClockTime() {
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T14:00:00Z")) == "in 2 hours, 14:00")
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T12:30:00Z")) == "in 30 minutes, 12:30")
    }

    @Test func ceilingRoundingOnFractionalHours() {
        // 2.5h away -> truncated whole hours 2 (< 4) -> ceil to 3 hours.
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T14:30:00Z")) == "in 3 hours, 14:30")
    }

    @Test func startedEarlierTodayPastLiveWindowShowsAgo() {
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T09:00:00Z")) == "3 hours ago, 09:00")
    }

    @Test func todayFourOrMoreHoursAwayIsTodayFormat() {
        // Exactly 4h is NOT < 4 -> falls through to "Today".
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T16:00:00Z")) == "Today, Fri 16:00")
        #expect(label(start: GroupDetailFixtures.date("2026-06-05T18:00:00Z")) == "Today, Fri 18:00")
    }

    @Test func tomorrowFormat() {
        #expect(label(start: GroupDetailFixtures.date("2026-06-06T15:00:00Z")) == "Tomorrow, Sat 15:00")
    }

    @Test func farDateFormat() {
        #expect(label(start: GroupDetailFixtures.date("2026-06-08T12:00:00Z")) == "Mon 08 Jun 12:00")
    }
}

@Suite("Game card logic (Game.vue awarded points + urgency pins)")
struct GroupGameCardLogicTests {
    private let finished = GroupDetailFixtures.game(id: 7, start: now.addingTimeInterval(-7200), status: 1)
    private let unfinished = GroupDetailFixtures.game(id: 7, start: now.addingTimeInterval(-7200))

    @Test func awardedPointsOnlyForFinishedGames() {
        let bet = GroupDetailFixtures.bet(userID: "me", gameID: 7, userPoints: 3, processed: true)
        #expect(GroupGameCardLogic.awardedPoints(game: finished, bets: [bet], userID: "me") == 3)
        #expect(GroupGameCardLogic.awardedPoints(game: unfinished, bets: [bet], userID: "me") == nil)
    }

    @Test func awardedPointsHiddenWithoutOwnBetOrWhenLoggedOut() {
        let other = GroupDetailFixtures.bet(userID: "someone-else", gameID: 7, userPoints: 3, processed: true)
        #expect(GroupGameCardLogic.awardedPoints(game: finished, bets: [other], userID: "me") == nil)
        #expect(GroupGameCardLogic.awardedPoints(game: finished, bets: [other], userID: nil) == nil)
    }

    @Test func awardedPointsNilForUnevaluatedOwnBet() {
        let bet = GroupDetailFixtures.bet(userID: "me", gameID: 7, userPoints: nil)
        #expect(GroupGameCardLogic.awardedPoints(game: finished, bets: [bet], userID: "me") == nil)
    }

    @Test func firstOwnBetWinsInArrayOrder() {
        let first = GroupDetailFixtures.bet(id: 1, userID: "me", gameID: 7, userPoints: 0, processed: true)
        let second = GroupDetailFixtures.bet(id: 2, userID: "me", gameID: 7, userPoints: 3, processed: true)
        #expect(GroupGameCardLogic.awardedPoints(game: finished, bets: [first, second], userID: "me") == 0)
    }

    @Test func urgencyBorders() {
        func game(hoursAway: Double) -> Game {
            GroupDetailFixtures.game(start: now.addingTimeInterval(hoursAway * 3600))
        }
        // Exactly 24h -> urgent only.
        #expect(GroupGameCardLogic.isUrgent(game: game(hoursAway: 24), at: now))
        #expect(!GroupGameCardLogic.isDanger(game: game(hoursAway: 24), at: now))
        // 13h -> urgent only.
        #expect(GroupGameCardLogic.isUrgent(game: game(hoursAway: 13), at: now))
        #expect(!GroupGameCardLogic.isDanger(game: game(hoursAway: 13), at: now))
        // Exactly 12h -> urgent + danger.
        #expect(GroupGameCardLogic.isUrgent(game: game(hoursAway: 12), at: now))
        #expect(GroupGameCardLogic.isDanger(game: game(hoursAway: 12), at: now))
        // 25h -> neither.
        #expect(!GroupGameCardLogic.isUrgent(game: game(hoursAway: 25), at: now))
        // Past -> neither.
        #expect(!GroupGameCardLogic.isUrgent(game: game(hoursAway: -1), at: now))
        // 24.5h -> truncates to 24 -> urgent (differenceInHours truncation pin).
        #expect(GroupGameCardLogic.isUrgent(game: game(hoursAway: 24.5), at: now))
    }

    @Test func urgentWindowOverridesBetDoneBorder() {
        let urgent = GroupDetailFixtures.game(start: now.addingTimeInterval(3600))
        #expect(GroupGameCardLogic.border(game: urgent, betted: true, at: now) == .urgent)
    }

    @Test func bettedGameOutsideUrgencyShowsBetDone() {
        let far = GroupDetailFixtures.game(start: now.addingTimeInterval(48 * 3600))
        #expect(GroupGameCardLogic.border(game: far, betted: true, at: now) == .betDone)
        #expect(GroupGameCardLogic.border(game: far, betted: false, at: now) == .none)
    }

    @Test func finishedBettedGameKeepsGreenBorder() {
        #expect(GroupGameCardLogic.border(game: finished, betted: true, at: now) == .betDone)
    }
}
