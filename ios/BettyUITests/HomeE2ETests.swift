import XCTest

/// E2E coverage for the Home dashboard (web `/dashboard`, screens.md §3.2): group cards
/// (names / placement / member counts), hero headline + first-kickoff countdown, the
/// need-action banner (urgent / today's / hidden + bet-sheet navigation), Running/Ended
/// classification incl. the 28-day recently-ended window, grouped/list card modes,
/// global and per-tab empty states, load-failure recovery, pull-to-refresh, and
/// navigation into group detail / create-group / browse / support.
final class HomeE2ETests: BettyUITestCase {
    private var home: HomeScreen { HomeScreen(app: app) }

    // MARK: - Groups list rendering

    func testGroupsListRendersNamesPlacementsAndMemberCounts() {
        launchToHome()
        waitFor(home.groupCard(named: "Sunday Legends"))
        XCTAssertTrue(staticText(containing: "★ EURO CUP 2026").exists) // kicker style uppercases
        XCTAssertTrue(app.staticTexts["3 MEMBERS"].exists)
        XCTAssertTrue(staticText(containing: "· 5 PTS").exists)
        XCTAssertTrue(app.staticTexts["#2"].exists)
        XCTAssertTrue(staticText(containing: "● ACTIVE").exists)
        XCTAssertTrue(staticText(containing: "OPEN GROUP →").exists)

        scrollTo(home.groupCard(named: "Office Royale"))
        XCTAssertTrue(app.staticTexts["2 MEMBERS"].exists)
        XCTAssertTrue(staticText(containing: "· 2 PTS").exists)

        scrollTo(home.groupCard(named: "Wrapped Winners"))
        XCTAssertTrue(staticText(containing: "· 9 PTS").exists)
        XCTAssertTrue(app.staticTexts["#1"].exists)
    }

    // MARK: - Running / Ended classification

    func testRecentlyEndedGroupStaysInRunningWithJustEndedBadge() {
        // Legacy League ended 10 days ago — inside the 28-day window, so Wrapped
        // Winners counts as Running with a JUST ENDED badge and the Ended tab is empty.
        launchToHome()
        scrollTo(home.runningTabButton)
        XCTAssertTrue(contains(home.runningTabButton, "3"))
        XCTAssertTrue(contains(home.endedTabButton, "0"))

        home.endedTabButton.tap()
        waitFor(home.tabEmptyCopy)
        XCTAssertTrue(home.tabEmptyCopy.label.contains("No tournaments have wrapped up yet"))
        XCTAssertTrue(staticText(containing: "LOOK BACK.").exists)

        home.runningTabButton.tap()
        scrollTo(home.groupCard(named: "Wrapped Winners"))
        XCTAssertTrue(staticText(containing: "JUST ENDED").exists)
    }

    func testEndedTabShowsGroupWhenTournamentEndedBeyondWindow() {
        withScenario { $0.homeEndTournamentBeyondRecentWindow(DefaultScenario.endedTournamentID) }
        launchToHome()
        scrollTo(home.runningTabButton)
        XCTAssertTrue(contains(home.runningTabButton, "2"))
        XCTAssertTrue(contains(home.endedTabButton, "1"))

        home.endedTabButton.tap()
        waitFor(home.groupCard(named: "Wrapped Winners"))
        XCTAssertTrue(staticText(containing: "○ ENDED").exists)
        XCTAssertTrue(staticText(containing: "SEE RESULTS →").exists)
        XCTAssertFalse(home.groupCard(named: "Sunday Legends").exists)
    }

    func testRunningTabEmptyCopyAndSingularHeadlineOnEndedTab() {
        withScenario { scenario in
            scenario.homeRemoveMembership(of: DefaultScenario.currentUserID,
                                          fromGroup: DefaultScenario.groupSundayLegendsID)
            scenario.homeRemoveMembership(of: DefaultScenario.currentUserID,
                                          fromGroup: DefaultScenario.groupOfficeRoyaleID)
            scenario.homeEndTournamentBeyondRecentWindow(DefaultScenario.endedTournamentID)
        }
        launchToHome()
        waitFor(home.heroHeadline)
        XCTAssertTrue(home.heroHeadline.label.contains("NO RUNNING"))
        XCTAssertTrue(home.heroHeadline.label.contains("GROUPS."))
        scrollTo(home.tabEmptyCopy)
        XCTAssertTrue(home.tabEmptyCopy.label.contains("No active tournaments right now"))
        XCTAssertFalse(home.needActionHeader.exists)

        home.endedTabButton.tap()
        waitFor(home.groupCard(named: "Wrapped Winners"))
        XCTAssertTrue(home.heroHeadline.label.contains("1 GROUP."))
        XCTAssertTrue(home.heroHeadline.label.contains("ONE CHAMPION."))
    }

    // MARK: - Hero headline + first-kickoff countdown

    func testHeroHeadlinePluralCountAndCountdownHiddenOnceKickedOff() {
        launchToHome()
        waitFor(home.heroHeadline)
        XCTAssertTrue(home.heroHeadline.label.contains("3 GROUPS."))
        XCTAssertTrue(home.heroHeadline.label.contains("ONE CHAMPION."))
        // Euro Cup kicked off 7 days ago — no future kickoff, countdown hidden.
        XCTAssertFalse(home.heroCountdown.exists)
    }

    func testHeroCountdownShowsForFutureKickoff() {
        withScenario { scenario in
            scenario.homeSetTournamentDates(DefaultScenario.runningTournamentID,
                                            start: Date().addingTimeInterval(2 * 86_400))
        }
        launchToHome()
        waitFor(home.heroCountdown)
        let inCountdown = home.heroCountdown.staticTexts
        XCTAssertTrue(inCountdown.matching(NSPredicate(format: "label CONTAINS %@", "FIRST KICKOFF IN")).firstMatch.exists)
        XCTAssertTrue(inCountdown.matching(NSPredicate(format: "label CONTAINS %@", "EURO CUP 2026")).firstMatch.exists) // kicker uppercases
        XCTAssertTrue(inCountdown["DAYS"].exists)
        XCTAssertTrue(inCountdown["HRS"].exists)
        XCTAssertTrue(inCountdown["MIN"].exists)
        XCTAssertTrue(inCountdown["SEC"].exists)
    }

    // MARK: - Need-action banner

    func testNeedActionUrgentBannerListsUnbetGameAndOpensBetSheet() {
        // DefaultScenario: game 11 kicks off in 2 h and is deliberately un-bet.
        launchToHome()
        waitFor(home.needActionHeader)
        XCTAssertTrue(home.needActionHeader.label.localizedCaseInsensitiveContains("make sure to bet"))

        let row = waitFor(home.needActionRow(DefaultScenario.upcomingGameID))
        XCTAssertTrue(contains(row, "Sweden"))
        XCTAssertTrue(contains(row, "England"))
        XCTAssertTrue(contains(row, "IN 1H"))
        XCTAssertFalse(home.needActionRow(DefaultScenario.liveGameID).exists)
        XCTAssertFalse(home.needActionRow(DefaultScenario.finishedGameID).exists)

        row.tap()
        waitFor(home.text(containingIgnoringCase: "place your bet"))
        XCTAssertTrue(home.text(containingIgnoringCase: "sweden vs england").exists)
    }

    func testNeedActionUrgentSortsByKickoffAndCapsAtThree() {
        withScenario { scenario in
            scenario.homeAddUpcomingGame(id: 14, startingIn: 30 * 60, homeTeamID: 102, awayTeamID: 103)
            scenario.homeAddUpcomingGame(id: 15, startingIn: 3 * 3600, homeTeamID: 104, awayTeamID: 101)
            scenario.homeAddUpcomingGame(id: 16, startingIn: 4 * 3600, homeTeamID: 101, awayTeamID: 104)
        }
        launchToHome()
        waitFor(home.needActionHeader)
        let row14 = waitFor(home.needActionRow(14))
        let row11 = waitFor(home.needActionRow(DefaultScenario.upcomingGameID))
        let row15 = waitFor(home.needActionRow(15))
        XCTAssertFalse(home.needActionRow(16).exists)
        XCTAssertLessThan(row14.frame.minY, row11.frame.minY)
        XCTAssertLessThan(row11.frame.minY, row15.frame.minY)
        XCTAssertTrue(contains(row14, " MIN"), "sub-hour kickoff renders an IN x MIN nudge")
    }

    func testNeedActionBetGameDoesNotTriggerUrgentWarning() {
        withScenario { scenario in
            scenario.homeBetEverywhere(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 1, away: 0)
        }
        launchToHome()
        waitFor(home.groupCard(named: "Sunday Legends"))
        waitForNeedActionInputs()
        XCTAssertFalse(home.text(containingIgnoringCase: "too late").exists)
    }

    func testNeedActionShowsTodaysGamesWhenNoUrgent() {
        // Anchor the upcoming game at 00:00 today: already started (never urgent) but
        // always on today's calendar day regardless of when the test runs.
        withScenario { scenario in
            scenario.updateGame(DefaultScenario.upcomingGameID) {
                $0.startDate = Calendar.current.startOfDay(for: Date())
            }
        }
        launchToHome()
        let header = waitFor(home.needActionHeader)
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("todays games"))
        XCTAssertFalse(home.text(containingIgnoringCase: "too late").exists)
        waitFor(home.needActionRow(DefaultScenario.upcomingGameID))
    }

    func testNeedActionHiddenWithoutUrgentOrTodayGames() {
        withScenario { scenario in
            scenario.updateGame(DefaultScenario.upcomingGameID) {
                $0.startDate = Date().addingTimeInterval(3 * 86_400)
            }
            scenario.updateGame(DefaultScenario.liveGameID) {
                $0.startDate = Date().addingTimeInterval(-3 * 86_400)
            }
        }
        launchToHome()
        waitFor(home.groupCard(named: "Sunday Legends"))
        waitForNeedActionInputs()
        XCTAssertFalse(home.needActionHeader.exists)
        XCTAssertFalse(home.needActionRow(DefaultScenario.upcomingGameID).exists)
    }

    func testNeedActionClearsWhenBetPlacedEventArrives() {
        launchToHome()
        waitFor(home.text(containingIgnoringCase: "too late"))
        waitForWebSocketClient()

        withScenario { scenario in
            scenario.homeBetEverywhere(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1)
        }
        pushWS(type: "bet_placed", message: MockWire.betEcho(
            userID: DefaultScenario.currentUserID,
            gameID: DefaultScenario.upcomingGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            home: 2, away: 1, isUniversal: true
        ))

        waitFor(home.text(containingIgnoringCase: "todays games"), timeout: 15)
        XCTAssertFalse(home.text(containingIgnoringCase: "too late").exists)
    }

    // MARK: - Empty state

    func testEmptyStateShowsCreateAndJoinCTAs() {
        withScenario { $0.homeRemoveAllMemberships(of: DefaultScenario.currentUserID) }
        launchToHome()
        waitFor(home.emptyHeadline)
        XCTAssertTrue(home.emptyHeadline.label.contains("SIX FRIENDS."))
        XCTAssertTrue(home.emptyHeadline.label.contains("ONE GROUP."))
        XCTAssertTrue(home.emptyStartGroupButton.exists)
        XCTAssertTrue(home.emptyJoinPublicButton.exists)
        XCTAssertTrue(home.heroHeadline.label.contains("NO GROUPS"))
        XCTAssertTrue(home.heroHeadline.label.contains("YET."))
        XCTAssertFalse(home.runningTabButton.exists)
        XCTAssertFalse(home.needActionHeader.exists)
    }

    func testEmptyStateStartGroupOpensCreateSheet() {
        withScenario { $0.homeRemoveAllMemberships(of: DefaultScenario.currentUserID) }
        launchToHome()
        scrollTo(home.emptyStartGroupButton)
        home.emptyStartGroupButton.tap()
        waitFor(CreateGroupScreen(app: app).title)
    }

    func testEmptyStateJoinPublicSwitchesToBrowseTab() {
        withScenario { $0.homeRemoveAllMemberships(of: DefaultScenario.currentUserID) }
        launchToHome()
        scrollTo(home.emptyJoinPublicButton)
        home.emptyJoinPublicButton.tap()
        waitFor(BrowseScreen(app: app).navigationBar)
    }

    // MARK: - Load failure

    func testLoadFailureShowsRetryCardAndRecovers() {
        backend.api("GET", "/user/:id/groups") { _, _, _, _ in .empty(500) }
        launchToHome()
        scrollTo(home.loadFailedRetryButton)
        XCTAssertTrue(staticText(containing: "Something went wrong while loading your groups").exists)

        backend.homeRestoreUserGroupsRoute()
        home.loadFailedRetryButton.tap()
        waitFor(home.groupCard(named: "Sunday Legends"), timeout: 15)
    }

    // MARK: - Pull-to-refresh

    func testPullToRefreshRefetchesGroupsAndTournaments() {
        launchToHome()
        waitFor(home.groupCard(named: "Sunday Legends"))

        withScenario { scenario in
            scenario.updateGroup(DefaultScenario.groupSundayLegendsID) { $0.name = "Sunday Legends Reborn" }
        }
        let groupsPath = "/api/v1/user/\(DefaultScenario.currentUserID)/groups"
        let groupsBefore = backend.requests(method: "GET", pathPrefix: groupsPath).count
        let tournamentsBefore = backend.requests(method: "GET", pathPrefix: "/api/v1/tournaments").count

        let renamed = home.groupCard(named: "Sunday Legends Reborn")
        for _ in 0..<3 where !renamed.exists {
            pullToRefresh()
            _ = renamed.waitForExistence(timeout: 5)
        }
        waitFor(renamed)
        XCTAssertGreaterThan(backend.requests(method: "GET", pathPrefix: groupsPath).count, groupsBefore)
        XCTAssertGreaterThan(backend.requests(method: "GET", pathPrefix: "/api/v1/tournaments").count, tournamentsBefore)
    }

    // MARK: - Navigation

    func testGroupCardNavigatesToGroupDetail() {
        launchToHome()
        scrollTo(home.groupCardLink(DefaultScenario.groupSundayLegendsID))
        home.groupCardLink(DefaultScenario.groupSundayLegendsID).tap()

        let detail = GroupDetailScreen(app: app)
        waitFor(detail.groupTab)
        XCTAssertTrue(detail.gamesTab.exists)
        XCTAssertTrue(detail.leaderboardTab.exists)
        XCTAssertTrue(staticText(containing: "SUNDAY LEGENDS").exists) // hero shows the name uppercased
    }

    func testFeedbackBannerOpensSupport() {
        launchToHome()
        waitFor(home.feedbackBanner)
        home.feedbackBanner.tap()
        waitFor(home.text(containingIgnoringCase: "need a hand"))
    }

    func testHeroNewGroupOpensCreateSheet() {
        launchToHome()
        XCTAssertTrue(home.newGroupButton.exists, "toolbar + button is present")
        scrollTo(home.heroNewGroupButton)
        home.heroNewGroupButton.tap()
        waitFor(CreateGroupScreen(app: app).title)
    }

    func testHeroBrowseLinkSwitchesToBrowseTab() {
        launchToHome()
        scrollTo(home.heroBrowseButton)
        home.heroBrowseButton.tap()
        waitFor(BrowseScreen(app: app).navigationBar)
    }

    // MARK: - Grouped / List card modes

    func testGroupedToggleStacksGroupsSharingTournamentAndNavigates() {
        launchToHome()
        scrollTo(home.groupedToggle)
        home.groupedToggle.tap()

        scrollTo(home.stackCountPill(tournamentID: DefaultScenario.runningTournamentID))
        XCTAssertEqual(home.stackCountPill(tournamentID: DefaultScenario.runningTournamentID).label, "2 GROUPS")
        scrollTo(home.stackRow(DefaultScenario.groupOfficeRoyaleID))
        XCTAssertTrue(home.stackRow(DefaultScenario.groupSundayLegendsID).exists)
        // Wrapped Winners is alone in its tournament bucket — degrades to a single card.
        scrollTo(home.groupCardLink(DefaultScenario.groupWrappedID))

        scrollUpTo(home.stackRow(DefaultScenario.groupOfficeRoyaleID))
        home.stackRow(DefaultScenario.groupOfficeRoyaleID).tap()
        let detail = GroupDetailScreen(app: app)
        waitFor(detail.groupTab)
        XCTAssertTrue(staticText(containing: "OFFICE ROYALE").exists) // hero shows the name uppercased
    }

    func testListToggleRestoresSingleCards() {
        launchToHome()
        scrollTo(home.groupedToggle)
        home.groupedToggle.tap()
        scrollTo(home.stackRow(DefaultScenario.groupSundayLegendsID))

        scrollUpTo(home.listToggle)
        home.listToggle.tap()
        scrollTo(home.groupCardLink(DefaultScenario.groupSundayLegendsID))
        XCTAssertFalse(home.stackRow(DefaultScenario.groupSundayLegendsID).exists)
        XCTAssertFalse(home.stackCountPill(tournamentID: DefaultScenario.runningTournamentID).exists)
    }

    // MARK: - Helpers

    private func launchToHome() {
        launchApp()
        waitFor(TabBarScreen(app: app).home, timeout: 30)
        waitFor(home.navigationBar, timeout: 15)
    }

    /// The need-action banner derives from per-group bet matrices fetched after the
    /// placements land — wait for those requests before asserting the banner's absence.
    private func waitForNeedActionInputs(timeout: TimeInterval = 10,
                                         file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if backend.requests(method: "GET", pathPrefix: "/api/v1/bets/bygroup").count >= 2 { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("Timed out waiting for the need-action bet matrices to be fetched",
                file: file, line: line)
    }

    /// SwiftUI doesn't always concatenate child texts into a button's label — accept a
    /// hit on either the aggregated label or a descendant static text.
    private func contains(_ container: XCUIElement, _ fragment: String) -> Bool {
        if container.label.contains(fragment) { return true }
        return container.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", fragment))
            .firstMatch.exists
    }

    /// Same geometry as the Tournaments-suite helper (verified to fire `.refreshable`):
    /// a 0.15 dy start lands in the large-title region where the drag doesn't reach the
    /// scroll content.
    private func pullToRefresh() {
        let scroll = app.scrollViews.firstMatch
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.15, thenDragTo: end)
    }

    /// Swipe-down twin of `scrollTo` — climbs back up a LazyVStack until the element is
    /// hittable (a top-edge swipe can fire `.refreshable`, which is harmless here).
    private func scrollUpTo(_ element: XCUIElement, maxSwipes: Int = 6,
                            file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeDown(velocity: .slow)
        }
        if !(element.exists && element.isHittable) {
            XCTFail("Element not hittable after scrolling up: \(element)", file: file, line: line)
        }
    }
}
