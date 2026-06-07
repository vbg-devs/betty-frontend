import Foundation

/// Tournaments-area fixtures: DefaultScenario variants with purpose-built schedules for
/// the running tournament (id 1). Default bets reference the replaced games, so each
/// variant clears `bets`. Dates are wall-clock-relative like DefaultScenario's (the
/// only race is a test starting within minutes of midnight).
enum TournamentsFixtures {
    static let todayGameID = 21
    static let tomorrowGameID = 22
    static let knockoutGameID = 23
    static let headerGameID = 31
    static let finishedOnlyGameID = 41

    /// Three upcoming games over three calendar days in two pools — pins flat-array
    /// joining, day grouping/ordering, the "● " next-upcoming marker, the
    /// "Group..."-suppression header rule, and the "<pool> - <day>" header for
    /// non-Group pools.
    /// Day 1 (today, Group A): Sweden–England. Day 2 (tomorrow noon, Group A):
    /// Spain–France. Day 3 (in 2 days noon, Knockout): Sweden–Spain.
    static func scheduleOrdering(now: Date = Date()) -> MockScenario {
        var scenario = DefaultScenario.build(now: now)
        let id = DefaultScenario.runningTournamentID
        replaceSchedule(
            &scenario,
            pools: [
                MockPool(id: 1, tournamentID: id, name: "Group A"),
                MockPool(id: 3, tournamentID: id, name: "Knockout"),
            ],
            games: [
                MockGame(id: todayGameID, tournamentID: id, poolID: 1,
                         homeTeamID: 101, awayTeamID: 102,
                         startDate: now.addingTimeInterval(10 * 60), status: nil),
                MockGame(id: tomorrowGameID, tournamentID: id, poolID: 1,
                         homeTeamID: 103, awayTeamID: 104,
                         startDate: noon(daysAhead: 1, from: now), status: nil),
                MockGame(id: knockoutGameID, tournamentID: id, poolID: 3,
                         homeTeamID: 101, awayTeamID: 103,
                         startDate: noon(daysAhead: 2, from: now), status: nil),
            ]
        )
        return scenario
    }

    /// One pool, one upcoming game tomorrow — short content keeps the detail header
    /// (image + name + dates) on screen despite the next-upcoming auto-scroll.
    static func singleUpcomingGame(now: Date = Date()) -> MockScenario {
        var scenario = DefaultScenario.build(now: now)
        let id = DefaultScenario.runningTournamentID
        replaceSchedule(
            &scenario,
            pools: [MockPool(id: 1, tournamentID: id, name: "Group A")],
            games: [
                MockGame(id: headerGameID, tournamentID: id, poolID: 1,
                         homeTeamID: 101, awayTeamID: 102,
                         startDate: noon(daysAhead: 1, from: now), status: nil),
            ]
        )
        return scenario
    }

    /// Only a finished game (status 1, 2-1, two days ago) — no upcoming day means no
    /// auto-scroll, so the past day renders from the top.
    static func finishedGameOnly(now: Date = Date()) -> MockScenario {
        var scenario = DefaultScenario.build(now: now)
        let id = DefaultScenario.runningTournamentID
        replaceSchedule(
            &scenario,
            pools: [MockPool(id: 2, tournamentID: id, name: "Group B")],
            games: [
                MockGame(id: finishedOnlyGameID, tournamentID: id, poolID: 2,
                         homeTeamID: 101, awayTeamID: 103,
                         homeTeamScore: 2, awayTeamScore: 1,
                         startDate: now.addingTimeInterval(-2 * 86_400),
                         updatedAt: now.addingTimeInterval(-2 * 86_400 + 2 * 3600),
                         status: 1),
            ]
        )
        return scenario
    }

    /// Noon `daysAhead` calendar days from `now` — always lands on that calendar day
    /// regardless of the current time of day.
    private static func noon(daysAhead: Int, from now: Date) -> Date {
        Calendar.current.startOfDay(for: now)
            .addingTimeInterval(TimeInterval(daysAhead) * 86_400 + 12 * 3600)
    }

    private static func replaceSchedule(_ scenario: inout MockScenario,
                                        pools: [MockPool], games: [MockGame]) {
        guard let index = scenario.tournaments.firstIndex(where: {
            $0.id == DefaultScenario.runningTournamentID
        }) else { return }
        scenario.tournaments[index].pools = pools
        scenario.tournaments[index].games = games
        scenario.bets = []
    }
}
