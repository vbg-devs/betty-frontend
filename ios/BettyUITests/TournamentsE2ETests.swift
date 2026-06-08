import XCTest

// E2E coverage for the Tournaments area: Browse → TOURNAMENTS list (cards, dates,
// empty state, pull-to-refresh), the tournament detail sheet (flat pools[]+games[]
// joined client-side into a day-grouped schedule, failure/retry, WS-forced reload),
// Browse → TEAMS (logos, monogram fallback, search), and the admin-gated evaluate
// flow (Profile → Admin, visible only with /user/me.is_admin).

/// Shared navigation + backend helpers for both tournaments suites. Kept on a private
/// base class (not a BettyUITestCase extension) so parallel area suites cannot collide.
class TournamentsAreaTestCase: BettyUITestCase {
    // MARK: - Navigation

    @discardableResult
    func openTournamentsSection() -> TournamentsListScreen {
        let screen = TournamentsListScreen(app: app)
        waitFor(TabBarScreen(app: app).browse, timeout: 30).tap()
        waitFor(screen.tournamentsSectionButton).tap()
        return screen
    }

    @discardableResult
    func openTeamsSection() -> TeamsBrowserScreen {
        waitFor(TabBarScreen(app: app).browse, timeout: 30).tap()
        waitFor(TournamentsListScreen(app: app).teamsSectionButton).tap()
        return TeamsBrowserScreen(app: app)
    }

    /// Opens the detail sheet for a list card.
    @discardableResult
    func openTournamentDetail(_ tournamentID: Int,
                              from list: TournamentsListScreen) -> TournamentDetailScreen {
        waitFor(list.card(tournamentID)).tap()
        return TournamentDetailScreen(app: app)
    }

    // MARK: - Assertion helpers

    /// The detail/list header dates exactly as `TournamentSchedule.tournamentDates`
    /// renders them ("MMM dd HH:mm - MMM dd HH:mm", fixed-English formatter).
    func tournamentHeaderDates(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    func detailRequestCount(tournamentID: Int) -> Int {
        backend.recordedRequests.filter {
            $0.method == "GET" && $0.path == "/api/v1/tournament/\(tournamentID)"
        }.count
    }

    /// Spins the run loop until a backend-observable condition holds (bounded wait —
    /// used where a UI signal alone cannot prove a request happened).
    func waitForBackend(timeout: TimeInterval = 10,
                        file: StaticString = #filePath, line: UInt = #line,
                        _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for backend condition", file: file, line: line)
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    // MARK: - Backend route control

    /// Replaces `GET /tournament/:id` with a switchable handler: while the returned
    /// flag is on it answers `failStatus`; off, it serves the live scenario again.
    func installTournamentDetailsFailure(status failStatus: Int) -> TournamentsRouteFlag {
        let failing = TournamentsRouteFlag(true)
        backend.api("GET", "/tournament/:id") { _, params, _, scenario in
            if failing.value { return .empty(failStatus) }
            guard let id = Int(params["id"] ?? ""),
                  let tournament = scenario.tournament(id), !tournament.hasEnded() else {
                return .empty(404)
            }
            return .json(MockWire.tournament(tournament, details: true))
        }
        return failing
    }

    /// Drags down far enough to trigger SwiftUI `.refreshable`.
    func pullToRefresh(on scrollView: XCUIElement) {
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.15, thenDragTo: end)
    }
}

/// Thread-safe toggle captured by overridden mock routes.
final class TournamentsRouteFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag: Bool

    init(_ initial: Bool) { flag = initial }

    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return flag }
        set { lock.lock(); flag = newValue; lock.unlock() }
    }
}

// MARK: - Tournaments list, detail sheet, teams browser (regular user)

final class TournamentsE2ETests: TournamentsAreaTestCase {
    // MARK: List

    /// One card per RUNNING tournament: name, "MMM dd HH:mm - MMM dd HH:mm" dates line,
    /// and the VIEW SCHEDULE call to action.
    func testTournamentsListShowsRunningTournamentCardWithDatesAndScheduleCTA() {
        launchApp()
        let list = openTournamentsSection()
        let card = waitFor(list.card(DefaultScenario.runningTournamentID))

        let (start, end) = withScenario { scenario -> (Date, Date) in
            let tournament = scenario.tournament(DefaultScenario.runningTournamentID)!
            return (tournament.startDate, tournament.endDate)
        }
        XCTAssertTrue(card.staticTexts["Euro Cup 2026"].exists)
        XCTAssertTrue(card.staticTexts[tournamentHeaderDates(start: start, end: end)].exists)
        XCTAssertTrue(card.staticTexts["VIEW SCHEDULE →"].exists)
    }

    /// Ended tournaments are listable on the wire but hidden from the cards (pinned).
    func testTournamentsListHidesEndedTournament() {
        launchApp()
        let list = openTournamentsSection()
        waitFor(list.card(DefaultScenario.runningTournamentID))
        XCTAssertFalse(list.card(DefaultScenario.endedTournamentID).exists)
        XCTAssertFalse(app.staticTexts["Legacy League"].exists)
    }

    /// A tournament without `image_url` renders the mascot placeholder artwork.
    func testTournamentsListShowsMascotPlaceholderWhenImageMissing() {
        launchApp()
        let list = openTournamentsSection()
        let card = waitFor(list.card(DefaultScenario.runningTournamentID))
        waitFor(list.placeholderArtwork(in: card))
    }

    /// No running tournaments → the NOTHING RUNNING inset panel.
    func testTournamentsListEmptyStateWhenNothingRunning() {
        withScenario { scenario in
            if let index = scenario.tournaments.firstIndex(where: {
                $0.id == DefaultScenario.runningTournamentID
            }) {
                scenario.tournaments[index].endDate = Date().addingTimeInterval(-3600)
            }
        }
        launchApp()
        let list = openTournamentsSection()
        let panel = waitFor(list.emptyPanel)
        XCTAssertTrue(panel.staticTexts["NOTHING RUNNING"].exists)
        XCTAssertTrue(panel.staticTexts["No running tournaments right now. Check back soon."].exists)
        XCTAssertFalse(list.card(DefaultScenario.runningTournamentID).exists)
    }

    /// Pull-to-refresh re-fetches `GET /tournaments` and renders newly running ones.
    func testTournamentsListPullToRefreshPicksUpNewTournament() {
        launchApp()
        let list = openTournamentsSection()
        waitFor(list.card(DefaultScenario.runningTournamentID))

        withScenario { scenario in
            scenario.tournaments.append(MockTournament(
                id: 5, name: "Copa Nova",
                startDate: Date().addingTimeInterval(86_400),
                endDate: Date().addingTimeInterval(30 * 86_400),
                categoryID: 1
            ))
        }

        let scroll = app.scrollViews
            .containing(.any, identifier: "tournaments.list.card.\(DefaultScenario.runningTournamentID)")
            .firstMatch
        for _ in 0..<3 where !list.card(5).exists {
            pullToRefresh(on: scroll)
            _ = list.card(5).waitForExistence(timeout: 3)
        }
        scrollTo(list.card(5))
        XCTAssertTrue(list.card(5).staticTexts["Copa Nova"].exists)
    }

    // MARK: Teams browser

    /// Bundled scheme art renders as an image (no monogram text); a missing or unknown
    /// `image_url` falls back to the first-letter monogram.
    func testTeamsBrowserShowsBundledLogosAndMonogramFallbacks() {
        withScenario { scenario in
            if let index = scenario.teams.firstIndex(where: { $0.id == 101 }) {
                scenario.teams[index].imageURL = "flag:se" // bundled asset flag/se
            }
            if let index = scenario.teams.firstIndex(where: { $0.id == 103 }) {
                scenario.teams[index].imageURL = "weird:xx" // unknown scheme
            }
        }
        launchApp()
        let teams = openTeamsSection()

        waitFor(teams.cell(101))
        XCTAssertTrue(teams.cell(101).staticTexts["SWEDEN"].exists)
        XCTAssertTrue(teams.cell(102).staticTexts["ENGLAND"].exists)
        XCTAssertTrue(teams.cell(103).staticTexts["SPAIN"].exists)
        XCTAssertTrue(teams.cell(104).staticTexts["FRANCE"].exists)

        // Bundled flag → image only, no monogram letter inside the logo circle.
        waitFor(teams.logo(101))
        XCTAssertFalse(teams.logo(101).staticTexts.firstMatch.exists)
        // Missing image_url → monogram.
        waitFor(teams.monogram(teamID: 102, letter: "E"))
        // Unknown scheme with no bundled asset → monogram.
        waitFor(teams.monogram(teamID: 103, letter: "S"))
    }

    /// The local name filter narrows the grid case-insensitively per keystroke.
    func testTeamsBrowserSearchFiltersTeams() {
        launchApp()
        let teams = openTeamsSection()
        waitFor(teams.cell(101))

        waitFor(teams.searchField).tap()
        teams.searchField.typeText("swe")

        waitForDisappearance(teams.cell(102))
        XCTAssertTrue(teams.cell(101).exists)
        XCTAssertFalse(teams.cell(103).exists)
        XCTAssertFalse(teams.cell(104).exists)
    }

    /// No matches → the NO TEAMS panel quoting the query; the clear button restores.
    func testTeamsBrowserNoMatchEmptyCopyAndClearRestores() {
        launchApp()
        let teams = openTeamsSection()
        waitFor(teams.cell(101))

        waitFor(teams.searchField).tap()
        teams.searchField.typeText("zzz")

        let panel = waitFor(teams.emptyPanel)
        XCTAssertTrue(panel.staticTexts["NO TEAMS"].exists)
        XCTAssertTrue(panel.staticTexts["No teams match \"zzz\"."].exists)

        waitFor(teams.clearSearchButton).tap()
        waitFor(teams.cell(101))
        XCTAssertTrue(teams.cell(104).exists)
        XCTAssertFalse(teams.emptyPanel.exists)
    }

    /// Empty teams table (404 → []) shows the pull-to-refresh empty copy.
    func testTeamsBrowserEmptyStoreShowsPullToRefreshCopy() {
        withScenario { $0.teams = [] }
        launchApp()
        let teams = openTeamsSection()

        let panel = waitFor(teams.emptyPanel)
        XCTAssertTrue(panel.staticTexts["NO TEAMS"].exists)
        XCTAssertTrue(panel.staticTexts["No teams loaded yet. Pull to refresh."].exists)
    }
}

// MARK: - Tournament detail sheet + admin gating (non-admin side)

final class TournamentsDetailE2ETests: TournamentsAreaTestCase {
    // MARK: Detail sheet

    /// Sheet header: tournament name + the "MMM dd HH:mm - MMM dd HH:mm" dates line.
    func testTournamentDetailHeaderShowsNameAndDates() {
        withScenario { $0 = TournamentsFixtures.singleUpcomingGame() }
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)

        let header = waitFor(detail.header)
        XCTAssertTrue(header.staticTexts["Euro Cup 2026"].exists)
        let (start, end) = withScenario { scenario -> (Date, Date) in
            let tournament = scenario.tournament(DefaultScenario.runningTournamentID)!
            return (tournament.startDate, tournament.endDate)
        }
        XCTAssertTrue(header.staticTexts[tournamentHeaderDates(start: start, end: end)].exists)
        // The single upcoming day is flagged next-upcoming; "Group A" pools collapse
        // to the day title alone.
        waitFor(detail.dayHeader("● Tomorrow"))
    }

    /// FLAT sibling pools[]+games[] join client-side: today's two Group-A games render
    /// under one "● Today" header with team names, the live game shows the LIVE badge
    /// and its running score, and "Group …" pool names are suppressed from headers.
    func testTournamentDetailJoinsFlatPoolsAndGamesIntoDaySchedule() {
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)

        waitFor(detail.dayHeader("● Today"))

        let upcoming = waitFor(detail.gameCard(DefaultScenario.upcomingGameID))
        XCTAssertTrue(upcoming.staticTexts["SWEDEN"].exists)
        XCTAssertTrue(upcoming.staticTexts["ENGLAND"].exists)

        let live = waitFor(detail.gameCard(DefaultScenario.liveGameID))
        XCTAssertTrue(live.staticTexts["SPAIN"].exists)
        XCTAssertTrue(live.staticTexts["FRANCE"].exists)
        XCTAssertTrue(live.staticTexts["LIVE"].exists)
        XCTAssertTrue(live.staticTexts["1"].exists)
        XCTAssertTrue(live.staticTexts["0"].exists)

        // Header rule: pool names containing "Group" never prefix the day title.
        let groupPrefixed = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "Group A -"))
        XCTAssertEqual(groupPrefixed.count, 0)
    }

    /// Schedule ordering across days: Today (next-upcoming marker) before Tomorrow
    /// before the day after; non-"Group" pools prefix the header ("Knockout - in 2 days").
    func testTournamentDetailOrdersDaysAndLabelsNonGroupPoolHeaders() {
        withScenario { $0 = TournamentsFixtures.scheduleOrdering() }
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)

        let today = waitFor(detail.dayHeader("● Today"))
        let tomorrow = waitFor(detail.dayHeader("Tomorrow"))
        XCTAssertLessThan(today.frame.minY, tomorrow.frame.minY)

        let todayCard = waitFor(detail.gameCard(TournamentsFixtures.todayGameID))
        XCTAssertTrue(todayCard.staticTexts["SWEDEN"].exists)
        XCTAssertTrue(todayCard.staticTexts["ENGLAND"].exists)
        let tomorrowCard = waitFor(detail.gameCard(TournamentsFixtures.tomorrowGameID))
        XCTAssertTrue(tomorrowCard.staticTexts["SPAIN"].exists)
        XCTAssertTrue(tomorrowCard.staticTexts["FRANCE"].exists)

        scrollTo(detail.dayHeader("Knockout - in 2 days"))
        XCTAssertTrue(detail.gameCard(TournamentsFixtures.knockoutGameID).exists)
    }

    /// A finished game (status 1) renders "Finished" with the final score under its
    /// past-day header ("2 days ago").
    func testTournamentDetailRendersFinishedGameWithFinalScore() {
        withScenario { $0 = TournamentsFixtures.finishedGameOnly() }
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)

        waitFor(detail.dayHeader("2 days ago"))
        let card = waitFor(detail.gameCard(TournamentsFixtures.finishedOnlyGameID))
        XCTAssertTrue(card.staticTexts["Finished"].exists)
        XCTAssertTrue(card.staticTexts["SWEDEN"].exists)
        XCTAssertTrue(card.staticTexts["SPAIN"].exists)
        XCTAssertTrue(card.staticTexts["2"].exists)
        XCTAssertTrue(card.staticTexts["1"].exists)
    }

    /// The sheet always fetches fresh on appear — every open issues GET /tournament/:id.
    func testTournamentDetailRefetchesOnEachOpen() {
        launchApp()
        let list = openTournamentsSection()
        waitFor(list.card(DefaultScenario.runningTournamentID))
        let baseline = detailRequestCount(tournamentID: DefaultScenario.runningTournamentID)

        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)
        waitFor(detail.dayHeader("● Today"))
        waitForBackend {
            self.detailRequestCount(tournamentID: DefaultScenario.runningTournamentID) > baseline
        }
        let afterFirstOpen = detailRequestCount(tournamentID: DefaultScenario.runningTournamentID)

        waitFor(detail.closeButton).tap()
        waitForDisappearance(detail.header)
        openTournamentDetail(DefaultScenario.runningTournamentID, from: list)
        waitFor(detail.dayHeader("● Today"))
        waitForBackend {
            self.detailRequestCount(tournamentID: DefaultScenario.runningTournamentID) > afterFirstOpen
        }
    }

    /// Detail-route failure (the contract 404s unknown/ended tournaments) shows the
    /// NOT AVAILABLE state; TRY AGAIN recovers once the backend serves again.
    func testTournamentDetailFailureShowsNotAvailableAndRetryRecovers() {
        let failing = installTournamentDetailsFailure(status: 404)
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)

        let failed = waitFor(detail.failedPanel)
        XCTAssertTrue(failed.staticTexts["NOT AVAILABLE."].exists)
        XCTAssertTrue(failed.staticTexts["This tournament could not be loaded — it may have ended."].exists)

        failing.value = false
        waitFor(detail.tryAgainButton).tap()
        waitFor(detail.dayHeader("● Today"))
        XCTAssertFalse(detail.failedPanel.exists)
    }

    /// An `evaluate_game` socket push force-reloads the open schedule: the upcoming
    /// game flips to "Finished" with the freshly evaluated score.
    func testEvaluateGameSocketPushReloadsOpenSchedule() {
        launchApp()
        let list = openTournamentsSection()
        let detail = openTournamentDetail(DefaultScenario.runningTournamentID, from: list)
        waitFor(detail.dayHeader("● Today"))
        waitForWebSocketClient()

        withScenario { scenario in
            scenario.updateGame(DefaultScenario.upcomingGameID) {
                $0.homeTeamScore = 3
                $0.awayTeamScore = 2
                $0.status = 1
            }
        }
        pushWS(type: "evaluate_game", message: [
            "game_id": DefaultScenario.upcomingGameID,
            "home_team_score": 3,
            "away_team_score": 2,
        ])

        let card = detail.gameCard(DefaultScenario.upcomingGameID)
        waitFor(card.staticTexts["Finished"], timeout: 15)
        XCTAssertTrue(card.staticTexts["3"].exists)
        XCTAssertTrue(card.staticTexts["2"].exists)
    }

    // MARK: Admin gating (non-admin side)

    /// The Profile → Admin entry is hidden unless `/user/me.is_admin`.
    func testProfileHidesAdminEntryForNonAdmin() {
        launchApp()
        waitFor(TabBarScreen(app: app).profile, timeout: 20).tap()
        waitFor(ProfileScreen(app: app).navigationBar)
        scrollTo(app.buttons["Support"])
        XCTAssertTrue(app.buttons["About"].exists)
        XCTAssertFalse(app.buttons["Admin"].exists)
        XCTAssertFalse(app.staticTexts["Admin"].exists)
    }
}

// MARK: - Admin evaluate flow (seeded as the is_admin user)

final class TournamentsAdminE2ETests: TournamentsAreaTestCase {
    override var seededUserID: String { DefaultScenario.adminUserID }

    @discardableResult
    private func openAdminScreen() -> AdminEvaluateScreen {
        waitFor(TabBarScreen(app: app).profile, timeout: 20).tap()
        waitFor(ProfileScreen(app: app).navigationBar)
        scrollTo(app.buttons["Admin"]).tap()
        let admin = AdminEvaluateScreen(app: app)
        waitFor(admin.navigationBar)
        return admin
    }

    /// Selects the running tournament and waits for its pending games to load.
    private func selectRunningTournament(_ admin: AdminEvaluateScreen) {
        waitFor(admin.tournamentCard(DefaultScenario.runningTournamentID)).tap()
        waitFor(admin.gameCard(DefaultScenario.liveGameID))
    }

    /// The admin entry is visible for is_admin and opens the evaluate screen listing
    /// only RUNNING tournaments.
    func testProfileShowsAdminEntryAndOpensEvaluateScreen() {
        launchApp()
        let admin = openAdminScreen()
        waitFor(admin.heroTitle)
        let card = waitFor(admin.tournamentCard(DefaultScenario.runningTournamentID))
        XCTAssertTrue(card.staticTexts["Euro Cup 2026"].exists)
        XCTAssertTrue(card.staticTexts["SELECT →"].exists)
        XCTAssertFalse(admin.tournamentCard(DefaultScenario.endedTournamentID).exists)
        XCTAssertFalse(app.staticTexts["Legacy League"].exists)
    }

    /// Selecting a tournament loads its un-evaluated games sorted by kickoff (the live
    /// game kicked off 45 min ago sorts before the +2 h upcoming game; the finished
    /// game is hidden). Re-selecting the same tournament does not refetch.
    func testSelectingTournamentListsPendingGamesSortedByKickoff() {
        launchApp()
        let admin = openAdminScreen()
        selectRunningTournament(admin)

        let live = waitFor(admin.gameCard(DefaultScenario.liveGameID))
        let upcoming = waitFor(admin.gameCard(DefaultScenario.upcomingGameID))
        XCTAssertLessThan(live.frame.minY, upcoming.frame.minY)
        XCTAssertFalse(admin.gameCard(DefaultScenario.finishedGameID).exists)
        XCTAssertTrue(app.staticTexts["● SELECTED"].exists)

        // Re-selecting the already-selected tournament is a no-op (no refetch).
        let fetches = detailRequestCount(tournamentID: DefaultScenario.runningTournamentID)
        admin.tournamentCard(DefaultScenario.runningTournamentID).tap()
        waitFor(admin.gameCard(DefaultScenario.liveGameID))
        XCTAssertEqual(detailRequestCount(tournamentID: DefaultScenario.runningTournamentID), fetches)
    }

    /// Full happy path: score sheet → native confirmation (verbatim web copy) →
    /// POST /evaluategame → success toast and the game leaves the pending list.
    func testEvaluateFlowPostsScoreRemovesGameAndToasts() {
        launchApp()
        let admin = openAdminScreen()
        selectRunningTournament(admin)

        admin.gameCard(DefaultScenario.liveGameID).tap()
        waitFor(admin.sheetTitle)
        waitFor(admin.homeScoreField).tap()
        admin.homeScoreField.typeText("2")
        admin.awayScoreField.tap()
        admin.awayScoreField.typeText("1")
        XCTAssertTrue(admin.submitButton.isEnabled)
        admin.submitButton.tap()

        waitFor(staticText(containing: "Report that Spain - France ended 2 - 1"))
        waitFor(admin.confirmEvaluateButton).tap()

        waitFor(staticText(containing: "Game evaluated!"))
        waitForDisappearance(admin.gameCard(DefaultScenario.liveGameID))
        XCTAssertTrue(admin.gameCard(DefaultScenario.upcomingGameID).exists)

        let posts = backend.requests(method: "POST", pathPrefix: "/api/v1/evaluategame")
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.bodyJSON?["game_id"] as? Int, DefaultScenario.liveGameID)
        XCTAssertEqual(posts.first?.bodyJSON?["home_team_score"] as? Int, 2)
        XCTAssertEqual(posts.first?.bodyJSON?["away_team_score"] as? Int, 1)
    }

    /// A game that has not kicked off shows the notice and keeps save disabled even
    /// with both scores entered.
    func testUpcomingGameShowsNoticeAndKeepsSaveDisabled() {
        launchApp()
        let admin = openAdminScreen()
        selectRunningTournament(admin)

        scrollTo(admin.gameCard(DefaultScenario.upcomingGameID)).tap()
        waitFor(admin.sheetTitle)
        waitFor(admin.notStartedNotice)
        admin.homeScoreField.tap()
        admin.homeScoreField.typeText("1")
        admin.awayScoreField.tap()
        admin.awayScoreField.typeText("1")
        XCTAssertFalse(admin.submitButton.isEnabled)
    }

    /// 410 Gone (already processed) renders the inline error and keeps the sheet open.
    func testAlreadyProcessedGameShowsInlineGoneError() {
        backend.http.route("POST", "/api/v1/evaluategame") { _, _ in .empty(410) }
        launchApp()
        let admin = openAdminScreen()
        selectRunningTournament(admin)

        admin.gameCard(DefaultScenario.liveGameID).tap()
        waitFor(admin.sheetTitle)
        waitFor(admin.homeScoreField).tap()
        admin.homeScoreField.typeText("2")
        admin.awayScoreField.tap()
        admin.awayScoreField.typeText("1")
        admin.submitButton.tap()
        waitFor(admin.confirmEvaluateButton).tap()

        waitFor(admin.errorText)
        XCTAssertEqual(admin.errorText.label, "This game was already evaluated.")
        XCTAssertTrue(admin.submitButton.exists) // sheet stays up for a retry
    }

    /// A failed tournament-details load shows the error toast + retry panel; TRY AGAIN
    /// recovers once the backend serves again.
    func testTournamentLoadFailureShowsRetryAndRecovers() {
        let failing = installTournamentDetailsFailure(status: 500)
        launchApp()
        let admin = openAdminScreen()
        waitFor(admin.tournamentCard(DefaultScenario.runningTournamentID)).tap()

        waitFor(staticText(containing: "Could not load tournament"))
        let panel = waitFor(admin.loadFailedPanel)
        XCTAssertTrue(panel.staticTexts["Could not load this tournament's games."].exists)

        failing.value = false
        waitFor(admin.tryAgainButton).tap()
        waitFor(admin.gameCard(DefaultScenario.liveGameID))
        XCTAssertFalse(admin.loadFailedPanel.exists)
    }

    /// Every game already evaluated → the NO GAMES TO EVALUATE panel.
    func testAllGamesEvaluatedShowsEmptyPanel() {
        withScenario { scenario in
            scenario.updateGame(DefaultScenario.upcomingGameID) { $0.status = 1 }
            scenario.updateGame(DefaultScenario.liveGameID) { $0.status = 1 }
        }
        launchApp()
        let admin = openAdminScreen()
        waitFor(admin.tournamentCard(DefaultScenario.runningTournamentID)).tap()

        let panel = waitFor(admin.noPendingGamesPanel)
        XCTAssertTrue(panel.staticTexts["Every game in this tournament has already been evaluated."].exists)
    }

    /// No running tournaments → the NOTHING RUNNING panel (nothing selectable).
    func testNothingRunningShowsEmptyTournamentsPanel() {
        withScenario { scenario in
            if let index = scenario.tournaments.firstIndex(where: {
                $0.id == DefaultScenario.runningTournamentID
            }) {
                scenario.tournaments[index].endDate = Date().addingTimeInterval(-3600)
            }
        }
        launchApp()
        let admin = openAdminScreen()

        let panel = waitFor(admin.noTournamentsPanel)
        XCTAssertTrue(panel.staticTexts["No ongoing tournaments right now. There is nothing to evaluate."].exists)
        XCTAssertFalse(admin.tournamentCard(DefaultScenario.runningTournamentID).exists)
    }
}
