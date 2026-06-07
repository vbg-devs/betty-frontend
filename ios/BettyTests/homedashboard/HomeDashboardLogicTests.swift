import Foundation
import Testing
@testable import Betty

// MARK: - fixtures (wire models are Decodable-only — fabricate via JSON)

private func decodeModel<T: Decodable>(_ json: String) -> T {
    try! JSONCoding.makeDecoder().decode(T.self, from: Data(json.utf8))
}

private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

/// Web test base: 2026-06-01T00:00:00Z.
private let base = date("2026-06-01T00:00:00Z")

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func makeTournament(
    id: Int,
    name: String = "Tournament",
    start: String = "2099-06-11T00:00:00Z",
    end: String? = "2099-07-19T00:00:00Z"
) -> Tournament {
    let endJSON = end.map { "\"\($0)\"" } ?? "null"
    return decodeModel("""
    {"id": \(id), "name": "\(name)", "image_url": "https://img.test/t\(id).png",
     "start_date": "\(start)", "end_date": \(endJSON), "category_id": 1}
    """)
}

private func makeGame(
    id: Int,
    start: String,
    status: Int? = 0,
    homeScore: Int? = nil,
    awayScore: Int? = nil
) -> Game {
    let statusJSON = status.map(String.init) ?? "null"
    let homeJSON = homeScore.map(String.init) ?? "null"
    let awayJSON = awayScore.map(String.init) ?? "null"
    return decodeModel("""
    {"id": \(id), "tournament_id": 1, "pool_id": 1, "home_team_id": 11, "away_team_id": 12,
     "home_team_score": \(homeJSON), "away_team_score": \(awayJSON),
     "start_date": "\(start)", "updated_at": null, "status": \(statusJSON)}
    """)
}

private func makePlacement(
    id: Int,
    name: String = "Group",
    tournamentID: Int = 1,
    headerImageURL: String? = nil,
    publicAt: String? = nil,
    placement: Int = 1,
    memberCount: Int = 3
) -> GroupPlacement {
    let headerJSON = headerImageURL.map { "\"\($0)\"" } ?? "null"
    let publicJSON = publicAt.map { "\"\($0)\"" } ?? "null"
    return decodeModel("""
    {"id": \(id), "name": "\(name)", "tournament_id": \(tournamentID),
     "tournament_name": "Tournament \(tournamentID)", "tournament_image_url": null,
     "header_image_url": \(headerJSON), "bet_mode": 0, "public_at": \(publicJSON),
     "created_at": "2026-01-01T00:00:00Z", "score": 0, "normalized_score": 0,
     "placement": \(placement), "member_count": \(memberCount)}
    """)
}

private func makeBet(gameID: Int, userID: String, groupID: Int = 10) -> Bet {
    decodeModel("""
    {"id": 1, "user_id": "\(userID)", "game_id": \(gameID), "group_id": \(groupID),
     "user_points": null, "home_team_score": 2, "away_team_score": 1,
     "is_universal": false, "processed_at": null,
     "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"}
    """)
}

private func classify(
    _ placements: [GroupPlacement],
    tournaments: [Tournament],
    now: Date = base
) -> [HomeGroupItem] {
    HomeDashboardLogic.classify(
        placements,
        tournament: { id in tournaments.first { $0.id == id } },
        now: now
    )
}

// MARK: - classification

@Suite struct HomeGroupClassificationTests {
    @Test func missingTournamentIsEndedButNeverRecentlyEnded() {
        let items = classify([makePlacement(id: 1, tournamentID: 999)], tournaments: [])
        #expect(items[0].ended)
        #expect(!items[0].recentlyEnded)
        #expect(HomeDashboardLogic.ended(items).count == 1)
        #expect(HomeDashboardLogic.running(items).isEmpty)
    }

    @Test func nilEndDateCountsAsRunning() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, end: nil)]
        )
        #expect(!items[0].ended)
    }

    @Test func endDateExactlyNowCountsAsRunning() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, end: "2026-06-01T00:00:00Z")]
        )
        #expect(!items[0].ended)
    }

    @Test func endedWithinFourWeeksIsRecentlyEndedAndStaysRunning() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, end: "2026-05-20T00:00:00Z")]
        )
        #expect(items[0].ended)
        #expect(items[0].recentlyEnded)
        #expect(HomeDashboardLogic.running(items).count == 1)
        #expect(HomeDashboardLogic.ended(items).isEmpty)
    }

    @Test func endedExactlyFourWeeksAgoIsNotRecentlyEnded() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, end: "2026-05-04T00:00:00Z")]
        )
        #expect(items[0].ended)
        #expect(!items[0].recentlyEnded)
        #expect(HomeDashboardLogic.ended(items).count == 1)
    }

    @Test func emptyHeaderImageStringIsTreatedAsMissing() {
        let items = classify(
            [makePlacement(id: 1, headerImageURL: "")],
            tournaments: [makeTournament(id: 1)]
        )
        #expect(items[0].headerImageURL == nil)
    }
}

// MARK: - headline

@Suite struct HomeHeadlineTests {
    @Test func singularGroupHeadline() {
        let headline = HomeDashboardLogic.headline(visibleCount: 1, totalCount: 1, tab: .running)
        #expect(headline == .groups(count: 1))
        #expect(headline.leadText == "1 ")
        #expect(headline.accentText == "GROUP.")
        #expect(headline.trailingText == "ONE CHAMPION.")
    }

    @Test func pluralGroupsHeadline() {
        let headline = HomeDashboardLogic.headline(visibleCount: 3, totalCount: 3, tab: .running)
        #expect(headline.leadText == "3 ")
        #expect(headline.accentText == "GROUPS.")
        #expect(headline.trailingText == "ONE CHAMPION.")
    }

    @Test func noRunningGroupsHeadline() {
        let headline = HomeDashboardLogic.headline(visibleCount: 0, totalCount: 2, tab: .running)
        #expect(headline == .noneRunning)
        #expect(headline.leadText == "NO RUNNING")
        #expect(headline.accentText == "GROUPS.")
        #expect(headline.trailingText == nil)
    }

    @Test func noEndedGroupsHeadline() {
        let headline = HomeDashboardLogic.headline(visibleCount: 0, totalCount: 2, tab: .ended)
        #expect(headline == .noneEnded)
        #expect(headline.leadText == "NO ENDED")
    }

    @Test func emptyHeadline() {
        let headline = HomeDashboardLogic.headline(visibleCount: 0, totalCount: 0, tab: .running)
        #expect(headline == .empty)
        #expect(headline.leadText == "NO GROUPS")
        #expect(headline.accentText == "YET.")
        #expect(headline.trailingText == nil)
    }
}

// MARK: - first-kickoff countdown

@Suite struct HomeKickoffTests {
    @Test func picksEarliestUpcomingKickoffAcrossRunningGroups() {
        let items = classify(
            [makePlacement(id: 1, tournamentID: 1), makePlacement(id: 2, tournamentID: 2)],
            tournaments: [
                makeTournament(id: 1, name: "Later Cup", start: "2026-06-20T00:00:00Z", end: "2026-08-01T00:00:00Z"),
                makeTournament(id: 2, name: "Sooner Cup", start: "2026-06-11T00:00:00Z", end: "2026-08-01T00:00:00Z"),
            ]
        )
        let kickoff = HomeDashboardLogic.nextKickoff(across: HomeDashboardLogic.running(items), now: base)
        #expect(kickoff?.tournament.name == "Sooner Cup")
        #expect(kickoff?.startDate == date("2026-06-11T00:00:00Z"))
    }

    @Test func hiddenWhenEveryRunningTournamentHasKickedOff() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, start: "2026-05-25T00:00:00Z", end: "2026-07-01T00:00:00Z")]
        )
        #expect(HomeDashboardLogic.nextKickoff(across: HomeDashboardLogic.running(items), now: base) == nil)
    }

    @Test func kickoffExactlyNowDoesNotCount() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, start: "2026-06-01T00:00:00Z", end: "2026-07-01T00:00:00Z")]
        )
        #expect(HomeDashboardLogic.nextKickoff(across: HomeDashboardLogic.running(items), now: base) == nil)
    }

    @Test func ignoresFutureKickoffsOfTournamentsThatAlreadyEnded() {
        let items = classify(
            [makePlacement(id: 1)],
            tournaments: [makeTournament(id: 1, start: "2026-06-10T00:00:00Z", end: "2026-04-01T00:00:00Z")]
        )
        #expect(HomeDashboardLogic.nextKickoff(across: HomeDashboardLogic.running(items), now: base) == nil)
    }

    @Test func countdownComponentsArePaddedWebStyle() {
        let countdown = HomeCountdown.until(date("2026-06-11T03:04:05Z"), now: base)
        #expect(countdown == HomeCountdown(days: 10, hours: 3, minutes: 4, seconds: 5))
        #expect(HomeCountdown.pad(countdown.days) == "10")
        #expect(HomeCountdown.pad(countdown.hours) == "03")
        #expect(HomeCountdown.pad(countdown.seconds) == "05")
        #expect(HomeCountdown.pad(100) == "100")
    }

    @Test func countdownClampsAtZeroWhenTargetPassed() {
        let countdown = HomeCountdown.until(date("2026-05-31T00:00:00Z"), now: base)
        #expect(countdown == HomeCountdown(days: 0, hours: 0, minutes: 0, seconds: 0))
    }
}

// MARK: - need action

@Suite struct HomeNeedActionTests {
    private let user = "uid-1"

    private func source(
        groupID: Int = 10,
        games: [Game],
        bets: [Bet] = []
    ) -> HomeNeedActionSource {
        HomeNeedActionSource(groupID: groupID, groupName: "Group \(groupID)", games: games, bets: bets)
    }

    @Test func gameExactly24HoursAwayIsNotUrgent() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-06-02T00:00:00Z")])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).isEmpty)
    }

    @Test func gameJustUnder24HoursAwayIsUrgent() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-06-01T23:59:00Z")])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).count == 1)
    }

    @Test func gameThirtyMinutesAwayIsUrgent() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-06-01T00:30:00Z")])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).count == 1)
    }

    @Test func pastUnfinishedGamesAreNotUrgent() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-05-31T23:00:00Z")])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).isEmpty)
    }

    @Test func finishedGamesAreNeverUrgent() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-06-01T12:00:00Z", status: 1)])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).isEmpty)
    }

    @Test func nilStatusCountsAsUnfinished() {
        let sources = [source(games: [makeGame(id: 1, start: "2026-06-01T12:00:00Z", status: nil)])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).count == 1)
    }

    @Test func ownBetRemovesUrgency() {
        let game = makeGame(id: 1, start: "2026-06-01T12:00:00Z")
        let sources = [source(games: [game], bets: [makeBet(gameID: 1, userID: user)])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).isEmpty)
    }

    @Test func otherUsersBetsDoNotRemoveUrgency() {
        let game = makeGame(id: 1, start: "2026-06-01T12:00:00Z")
        let sources = [source(games: [game], bets: [makeBet(gameID: 1, userID: "uid-other")])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: user, now: base).count == 1)
    }

    @Test func loggedOutTreatsEveryGameAsUnbet() {
        let game = makeGame(id: 1, start: "2026-06-01T12:00:00Z")
        let sources = [source(games: [game], bets: [makeBet(gameID: 1, userID: user)])]
        #expect(HomeDashboardLogic.urgentEntries(sources: sources, userID: nil, now: base).count == 1)
    }

    @Test func capsUrgentAtThreeSortedByStartAcrossGroups() {
        let a = source(groupID: 10, games: [
            makeGame(id: 1, start: "2026-06-01T20:00:00Z"),
            makeGame(id: 2, start: "2026-06-01T05:00:00Z"),
        ])
        let b = source(groupID: 20, games: [
            makeGame(id: 3, start: "2026-06-01T10:00:00Z"),
            makeGame(id: 4, start: "2026-06-01T15:00:00Z"),
        ])
        let urgent = HomeDashboardLogic.urgentEntries(sources: [a, b], userID: user, now: base)
        #expect(urgent.map(\.game.id) == [2, 3, 4])
    }

    @Test func gameBetInOneGroupSurfacesForTheUnbetGroup() {
        let game = makeGame(id: 5, start: "2026-06-01T12:00:00Z")
        let betted = source(groupID: 10, games: [game], bets: [makeBet(gameID: 5, userID: user, groupID: 10)])
        let unbet = source(groupID: 20, games: [game])
        let urgent = HomeDashboardLogic.urgentEntries(sources: [betted, unbet], userID: user, now: base)
        #expect(urgent.count == 1)
        #expect(urgent[0].groupID == 20)
    }

    @Test func duplicateGameUnbetInBothGroupsAppearsOnceForTheFirstGroup() {
        let game = makeGame(id: 5, start: "2026-06-01T12:00:00Z")
        let urgent = HomeDashboardLogic.urgentEntries(
            sources: [source(groupID: 10, games: [game]), source(groupID: 20, games: [game])],
            userID: user,
            now: base
        )
        #expect(urgent.count == 1)
        #expect(urgent[0].groupID == 10)
    }

    @Test func todaysGamesIncludeStartedFinishedAndBetGames() {
        let now = date("2026-06-01T12:00:00Z")
        let started = makeGame(id: 1, start: "2026-06-01T10:00:00Z")
        let finished = makeGame(id: 2, start: "2026-06-01T08:00:00Z", status: 1, homeScore: 2, awayScore: 0)
        let tomorrow = makeGame(id: 3, start: "2026-06-02T13:00:00Z")
        let sources = [source(games: [started, finished, tomorrow])]
        let today = HomeDashboardLogic.todaysEntries(sources: sources, userID: user, now: now, calendar: utcCalendar)
        #expect(today.map(\.game.id) == [2, 1])
    }

    @Test func todaysEntryCarriesTheFirstOwnBet() {
        let now = date("2026-06-01T06:00:00Z")
        let game = makeGame(id: 1, start: "2026-06-01T18:00:00Z")
        let bet = makeBet(gameID: 1, userID: user)
        let sources = [source(games: [game], bets: [bet])]
        let display = HomeDashboardLogic.needActionDisplay(sources: sources, userID: user, now: now, calendar: utcCalendar)
        guard case .today(let entries) = display else {
            Issue.record("expected .today, got \(display)")
            return
        }
        #expect(entries.count == 1)
        #expect(entries[0].ownBet == bet)
        #expect(entries[0].hasOwnBet)
    }

    @Test func urgentWinsOverTodaysGames() {
        let now = date("2026-06-01T06:00:00Z")
        let unbet = makeGame(id: 1, start: "2026-06-01T18:00:00Z")
        let finished = makeGame(id: 2, start: "2026-06-01T01:00:00Z", status: 1)
        let display = HomeDashboardLogic.needActionDisplay(
            sources: [source(games: [unbet, finished])],
            userID: user,
            now: now,
            calendar: utcCalendar
        )
        guard case .urgent(let entries) = display else {
            Issue.record("expected .urgent, got \(display)")
            return
        }
        #expect(entries.map(\.game.id) == [1])
    }

    @Test func hiddenWhenNothingUrgentAndNothingToday() {
        let display = HomeDashboardLogic.needActionDisplay(
            sources: [source(games: [makeGame(id: 1, start: "2026-06-05T12:00:00Z")])],
            userID: user,
            now: base,
            calendar: utcCalendar
        )
        #expect(display == .hidden)
    }

    @Test func hiddenWhenNoSources() {
        let display = HomeDashboardLogic.needActionDisplay(sources: [], userID: user, now: base, calendar: utcCalendar)
        #expect(display == .hidden)
    }
}

// MARK: - grouped cards

@Suite struct HomeCardsTests {
    private let tournaments = [
        makeTournament(id: 1, name: "World Cup 2026"),
        makeTournament(id: 2, name: "Copa 2026"),
    ]

    @Test func listModeKeepsEveryGroupAsASingleCardInOrder() {
        let items = classify(
            [makePlacement(id: 1), makePlacement(id: 2), makePlacement(id: 3, tournamentID: 2)],
            tournaments: tournaments
        )
        let cards = HomeDashboardLogic.cards(visible: items, grouped: false)
        #expect(cards.map(\.id) == ["g-1", "g-2", "g-3"])
    }

    @Test func groupedModeStacksGroupsSharingATournament() {
        let items = classify(
            [
                makePlacement(id: 1, name: "Alpha"),
                makePlacement(id: 2, name: "Beta"),
                makePlacement(id: 3, name: "Solo", tournamentID: 2),
            ],
            tournaments: tournaments
        )
        let cards = HomeDashboardLogic.cards(visible: items, grouped: true)
        #expect(cards.map(\.id) == ["t-1", "g-3"])
        guard case .stack(let tournament, let stacked, _, _) = cards[0] else {
            Issue.record("expected a stack card")
            return
        }
        #expect(tournament.name == "World Cup 2026")
        #expect(stacked.map(\.placement.name) == ["Alpha", "Beta"])
    }

    @Test func headerImageGroupsStaySingleAndComeBeforeBuckets() {
        let items = classify(
            [
                makePlacement(id: 1),
                makePlacement(id: 2, headerImageURL: "https://img.test/h.jpg"),
                makePlacement(id: 3),
                makePlacement(id: 4, tournamentID: 2),
            ],
            tournaments: tournaments
        )
        let cards = HomeDashboardLogic.cards(visible: items, grouped: true)
        // Web order: inline singles first, then buckets in first-seen order
        // (1-group buckets degrade to singles).
        #expect(cards.map(\.id) == ["g-2", "t-1", "g-4"])
    }

    @Test func groupsWithoutATournamentStaySingleWhenGrouped() {
        let items = classify(
            [makePlacement(id: 1, tournamentID: 999), makePlacement(id: 2, tournamentID: 999)],
            tournaments: tournaments
        )
        let cards = HomeDashboardLogic.cards(visible: items, grouped: true)
        #expect(cards.map(\.id) == ["g-1", "g-2"])
    }

    @Test func emptyHeaderImageStringGroupsAreStillBucketed() {
        let items = classify(
            [makePlacement(id: 1, headerImageURL: ""), makePlacement(id: 2)],
            tournaments: tournaments
        )
        let cards = HomeDashboardLogic.cards(visible: items, grouped: true)
        #expect(cards.map(\.id) == ["t-1"])
    }

    @Test func stackCardCarriesEndedAndRecentlyEndedFlags() {
        let endedTournament = makeTournament(id: 1, start: "2026-04-01T00:00:00Z", end: "2026-05-20T00:00:00Z")
        let items = classify(
            [makePlacement(id: 1), makePlacement(id: 2)],
            tournaments: [endedTournament]
        )
        let cards = HomeDashboardLogic.cards(visible: HomeDashboardLogic.running(items), grouped: true)
        guard case .stack(_, _, let ended, let recentlyEnded) = cards[0] else {
            Issue.record("expected a stack card")
            return
        }
        #expect(ended)
        #expect(recentlyEnded)
    }
}
