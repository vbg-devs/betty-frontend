import Foundation
import Testing
@testable import Betty

// Fixed clock: Monday 2026-06-15 12:00 UTC — the same instant the web Pools tests pin.
private let now = ISO8601DateFormatter().date(from: "2026-06-15T12:00:00Z")!

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

private func makeGame(
    id: Int,
    poolID: Int = 1,
    start: String,
    status: Int? = 0,
    homeScore: Int? = nil,
    awayScore: Int? = nil
) throws -> Game {
    let json = """
    {
      "id": \(id),
      "tournament_id": 42,
      "pool_id": \(poolID),
      "home_team_id": 1,
      "away_team_id": 2,
      "home_team_score": \(homeScore.map(String.init) ?? "null"),
      "away_team_score": \(awayScore.map(String.init) ?? "null"),
      "start_date": "\(start)",
      "status": \(status.map(String.init) ?? "null")
    }
    """
    return try JSONCoding.makeDecoder().decode(Game.self, from: Data(json.utf8))
}

private func makePool(id: Int, name: String, games: [Game]) -> PoolGames {
    PoolGames(pool: Pool(id: id, tournamentID: 42, name: name), games: games)
}

@Suite struct TournamentScheduleDayGroupingTests {
    @Test func emptyPoolsProduceNoDays() throws {
        #expect(TournamentSchedule.days(pools: [], now: now, calendar: utc).isEmpty)
        let empty = makePool(id: 1, name: "Group A", games: [])
        #expect(TournamentSchedule.days(pools: [empty], now: now, calendar: utc).isEmpty)
    }

    @Test func flattensPoolsAndSortsGamesByStartDateAcrossPools() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-16T18:00:00Z"),
                try makeGame(id: 2, start: "2026-06-14T10:00:00Z"),
            ]),
            makePool(id: 2, name: "Group B", games: [
                try makeGame(id: 3, poolID: 2, start: "2026-06-15T15:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.flatMap(\.entries).map(\.id) == [2, 3, 1])
    }

    @Test func groupsGamesOfTheSameCalendarDayTogether() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-16T10:00:00Z"),
                try makeGame(id: 2, start: "2026-06-16T20:00:00Z"),
                try makeGame(id: 3, start: "2026-06-17T10:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.count == 2)
        #expect(days.map { $0.entries.count } == [2, 1])
    }

    @Test func titlesDaysAsTodayTomorrowOrRelativeDistance() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-13T10:00:00Z"),
                try makeGame(id: 2, start: "2026-06-15T18:00:00Z"),
                try makeGame(id: 3, start: "2026-06-16T18:00:00Z"),
                try makeGame(id: 4, start: "2026-06-18T18:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.map(\.title) == ["2 days ago", "Today", "Tomorrow", "in 3 days"])
        // Group-pool day: the header is the day title only.
        #expect(days.map(\.headerText) == ["2 days ago", "Today", "Tomorrow", "in 3 days"])
    }

    @Test func prefixesHeaderWithPoolNameWhenItDoesNotContainGroup() throws {
        let pools = [
            makePool(id: 1, name: "Quarter-final", games: [
                try makeGame(id: 1, start: "2026-06-16T18:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.first?.headerText == "Quarter-final - Tomorrow")
    }

    @Test func combinesMixedPoolNamesInStartOrder() throws {
        let pools = [
            makePool(id: 1, name: "Round of 16", games: [
                try makeGame(id: 1, start: "2026-06-16T15:00:00Z"),
            ]),
            makePool(id: 2, name: "Quarter-final", games: [
                try makeGame(id: 2, poolID: 2, start: "2026-06-16T09:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.count == 1)
        #expect(days.first?.headerText == "Quarter-final & Round of 16 - Tomorrow")
    }

    @Test func showsOnlyDayTitleWhenMixedDayIncludesAGroupPool() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-16T15:00:00Z"),
            ]),
            makePool(id: 2, name: "Knockout", games: [
                try makeGame(id: 2, poolID: 2, start: "2026-06-16T09:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.count == 1)
        #expect(days.first?.headerText == "Tomorrow")
    }

    @Test func marksTheFirstDayStartingNowOrLaterAsNextUpcoming() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-14T18:00:00Z"),
                try makeGame(id: 2, start: "2026-06-15T18:00:00Z"),
                try makeGame(id: 3, start: "2026-06-16T18:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.map(\.isNextUpcoming) == [false, true, false])
    }

    @Test func flagsTodayWhenItsFirstGameStartedButALaterOneHasNot() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-15T09:00:00Z"),
                try makeGame(id: 2, start: "2026-06-15T20:00:00Z"),
                try makeGame(id: 3, start: "2026-06-16T18:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.map(\.isNextUpcoming) == [true, false])
    }

    @Test func marksNoDayWhenAllGamesAreInThePast() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-13T10:00:00Z"),
                try makeGame(id: 2, start: "2026-06-14T10:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.allSatisfy { !$0.isNextUpcoming })
    }

    @Test func entriesKeepTheirPoolName() throws {
        let pools = [
            makePool(id: 1, name: "Group A", games: [
                try makeGame(id: 1, start: "2026-06-16T15:00:00Z"),
            ]),
            makePool(id: 2, name: "Knockout", games: [
                try makeGame(id: 2, poolID: 2, start: "2026-06-16T09:00:00Z"),
            ]),
        ]
        let days = TournamentSchedule.days(pools: pools, now: now, calendar: utc)
        #expect(days.flatMap(\.entries).map(\.poolName) == ["Knockout", "Group A"])
    }
}

@Suite struct TournamentGameDateLabelTests {
    @Test func finishedGamesReadFinished() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T09:00:00Z", status: 1)
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "Finished")
    }

    @Test func todayWithinFourHoursIsStrictRelativePlusClockTime() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T14:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "in 2 hours, 14:00")
    }

    @Test func earlierTodayIsRelativePast() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T09:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "3 hours ago, 09:00")
    }

    @Test func minutesAwayUsesMinutes() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T12:30:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "in 30 minutes, 12:30")
    }

    @Test func ceilingRoundsTheRelativeValue() throws {
        // 3h59m away — truncated whole hours (3) stays under the 4h cutoff, but the
        // strict distance ceils to 4 hours (date-fns roundingMethod: ceil).
        let game = try makeGame(id: 1, start: "2026-06-15T15:59:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "in 4 hours, 15:59")
    }

    @Test func todayBeyondFourHoursUsesTodayFormat() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T18:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "Today, Mon 18:00")
    }

    @Test func exactlyFourHoursAwayIsNotRelative() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T16:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "Today, Mon 16:00")
    }

    @Test func tomorrowUsesTomorrowFormat() throws {
        let game = try makeGame(id: 1, start: "2026-06-16T18:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "Tomorrow, Tue 18:00")
    }

    @Test func fartherDatesUseTheFullFormat() throws {
        let game = try makeGame(id: 1, start: "2026-06-18T15:00:00Z")
        #expect(TournamentSchedule.dateLabel(for: game, now: now, calendar: utc) == "Thu 18 Jun 15:00")
    }

    @Test func strictRelativeSingularUnits() {
        #expect(TournamentSchedule.strictRelative(to: now.addingTimeInterval(3600), from: now) == "in 1 hour")
        #expect(TournamentSchedule.strictRelative(to: now.addingTimeInterval(60), from: now) == "in 1 minute")
        #expect(TournamentSchedule.strictRelative(to: now.addingTimeInterval(-45), from: now) == "45 seconds ago")
        #expect(TournamentSchedule.strictRelative(to: now, from: now) == "0 seconds ago")
    }
}

@Suite struct TournamentDatesFormattingTests {
    @Test func formatsStartAndEndAsMonthDayClock() {
        let start = ISO8601DateFormatter().date(from: "2026-06-11T18:30:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-07-19T21:00:00Z")!
        #expect(TournamentSchedule.tournamentDates(start: start, end: end, calendar: utc) == "Jun 11 18:30 - Jul 19 21:00")
    }

    @Test func missingEndDateRendersStartOnly() {
        let start = ISO8601DateFormatter().date(from: "2026-06-11T18:30:00Z")!
        #expect(TournamentSchedule.tournamentDates(start: start, end: nil, calendar: utc) == "Jun 11 18:30")
    }
}

@Suite struct TournamentDetailJoinTests {
    private func decodeTournament(pools: String, games: String) throws -> Tournament {
        let json = """
        {
          "id": 42,
          "name": "World Cup 2026",
          "image_url": "https://example.com/wc.png",
          "start_date": "2026-06-11T18:30:00Z",
          "end_date": "2026-07-19T21:00:00Z",
          "category_id": 1,
          "pools": \(pools),
          "games": \(games)
        }
        """
        return try JSONCoding.makeDecoder().decode(Tournament.self, from: Data(json.utf8))
    }

    private func gameJSON(id: Int, poolID: Int) -> String {
        """
        {"id": \(id), "tournament_id": 42, "pool_id": \(poolID), "home_team_id": 1,
         "away_team_id": 2, "home_team_score": null, "away_team_score": null,
         "start_date": "2026-06-12T15:00:00Z", "status": 0}
        """
    }

    @Test func attachesGamesToPoolsPreservingPoolOrder() throws {
        let pools = """
        [{"id": 1, "tournament_id": 42, "name": "Group A"},
         {"id": 2, "tournament_id": 42, "name": "Group B"}]
        """
        let games = "[\(gameJSON(id: 10, poolID: 1)), \(gameJSON(id: 12, poolID: 2)), \(gameJSON(id: 11, poolID: 1))]"
        let tournament = try decodeTournament(pools: pools, games: games)

        let joined = tournament.poolsWithGames
        #expect(joined.map(\.pool.name) == ["Group A", "Group B"])
        #expect(joined[0].games.map(\.id) == [10, 11])
        #expect(joined[1].games.map(\.id) == [12])
    }

    @Test func dropsGamesWithUnknownPoolAndKeepsEmptyPools() throws {
        let pools = #"[{"id": 1, "tournament_id": 42, "name": "Group A"}]"#
        let games = "[\(gameJSON(id: 99, poolID: 999))]"
        let tournament = try decodeTournament(pools: pools, games: games)

        let joined = tournament.poolsWithGames
        #expect(joined.count == 1)
        #expect(joined[0].games.isEmpty)
    }

    @Test func nullPoolsAndGamesJoinToEmpty() throws {
        let tournament = try decodeTournament(pools: "null", games: "null")
        #expect(tournament.poolsWithGames.isEmpty)
    }
}
