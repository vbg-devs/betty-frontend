import XCTest

/// Live area (WebSocket + live updates + toast/notify patterns) — data-layer §8/§12,
/// screens §3.8, api-contract §4.
///
/// Connection lifecycle tests run against `LiveSocketProbe` (an instrumented WS server
/// the test points `BETTY_WS_URL` at) so the mock OBSERVES handshakes, disconnects and
/// the app's `{"type":"ping"}` keepalives. Event-driven UI tests use the harness
/// backend's WS server via `pushWS`.
class LiveE2EBase: BettyUITestCase {

    // MARK: - Helpers

    /// Boots to Home (seeded auth) and pushes into a group's detail screen.
    func openGroup(_ name: String) {
        let home = HomeScreen(app: app)
        waitFor(TabBarScreen(app: app).home, timeout: 30)
        waitFor(home.navigationBar, timeout: 15)
        scrollTo(home.groupCard(named: name))
        home.groupCard(named: name).tap()
    }

    /// Opens the Activity tab and returns its page object.
    @discardableResult
    func openActivityTab() -> ActivityScreen {
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.activity, timeout: 20)
        tabs.activity.tap()
        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 10)
        return activity
    }
}

final class LiveConnectionE2ETests: LiveE2EBase {

    /// Starts an instrumented WS server and points the app's launch environment at it.
    private func makeProbe() throws -> LiveSocketProbe {
        let probe = LiveSocketProbe()
        try probe.start()
        addTeardownBlock { probe.stop() }
        app.launchEnvironment["BETTY_WS_URL"] = probe.url.absoluteString
        return probe
    }

    // MARK: - Connection lifecycle (data-layer §8)

    /// Signed-in launch opens exactly ONE socket for the whole app and the client
    /// sends a `{"type":"ping"}` keepalive every ~10 s (api-contract §4).
    func testWebSocketConnectsOnLaunchAndSendsKeepalivePings() throws {
        let probe = try makeProbe()
        launchApp()

        waitFor(TabBarScreen(app: app).home, timeout: 20)
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 1, timeout: 20),
                      "App never connected to the WS probe")

        XCTAssertTrue(probe.waitForTextFrames(atLeast: 2, timeout: 35),
                      "Expected at least two client keepalive pings")
        let pings = probe.recordedTextFrames.filter { $0.text.contains("\"ping\"") }
        XCTAssertGreaterThanOrEqual(pings.count, 2, "Client frames must be {\"type\":\"ping\"} keepalives")
        if pings.count >= 2 {
            let gap = pings[1].receivedAt.timeIntervalSince(pings[0].receivedAt)
            XCTAssertGreaterThan(gap, 4, "Keepalive pings should be ~10 s apart, got \(gap)s")
            XCTAssertLessThan(gap, 20, "Keepalive pings should be ~10 s apart, got \(gap)s")
        }

        // One app-wide socket — navigating tabs must not open more connections.
        let tabs = TabBarScreen(app: app)
        tabs.activity.tap()
        tabs.home.tap()
        XCTAssertEqual(probe.handshakeCount, 1, "Tab navigation must reuse the single app socket")
        XCTAssertEqual(probe.activeClientCount, 1)
    }

    /// Server-side closes trigger automatic reconnects (1 s base backoff) and the
    /// reconnected socket delivers events end-to-end.
    func testServerClosedSocketReconnectsAutomatically() throws {
        let probe = try makeProbe()
        launchApp()

        let activity = openActivityTab()
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 1, timeout: 20))

        let closedAt = Date()
        probe.closeActiveClients()
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 2, timeout: 20),
                      "App did not reconnect after a server-side close")
        if probe.handshakeDates.count >= 2 {
            let delay = probe.handshakeDates[1].timeIntervalSince(closedAt)
            XCTAssertGreaterThan(delay, 0.5, "Reconnect should respect the 1 s base backoff, got \(delay)s")
        }

        // A second close reconnects again (backoff reset to base by the received
        // greeting frame on the healthy connection in between).
        probe.closeActiveClients()
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 3, timeout: 25),
                      "App did not survive a second server-side close")
        XCTAssertTrue(probe.waitForActiveClients(1, timeout: 10))

        // The reconnected socket is live end-to-end: a push renders in the feed.
        probe.pushEvent(type: "group_created")
        waitFor(activity.row(containing: "New group on Betty"), timeout: 15)
    }

    /// Backgrounding closes the socket; returning to the foreground reconnects it and
    /// events flow again (data-layer §13.3).
    func testBackgroundingDisconnectsSocketAndForegroundingReconnects() throws {
        let probe = try makeProbe()
        launchApp()

        let activity = openActivityTab()
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 1, timeout: 20))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(probe.waitForActiveClients(0, timeout: 20),
                      "Backgrounding must close the socket")

        app.activate()
        XCTAssertTrue(probe.waitForHandshakes(atLeast: 2, timeout: 20),
                      "Foregrounding must reconnect the socket")
        XCTAssertTrue(probe.waitForActiveClients(1, timeout: 10))

        probe.pushEvent(type: "group_left")
        waitFor(activity.row(containing: "Someone just left a group"), timeout: 15)
    }
}

final class LiveE2ETests: LiveE2EBase {

    // MARK: - evaluate_game → live score refresh (the wire's ONLY store mutation)

    /// An `evaluate_game` push refreshes the open group's tournament details: the live
    /// game's score on the GAMES tab changes with NO pull-to-refresh or tab switch.
    func testEvaluateGameEventUpdatesVisibleLiveScoreWithoutRefresh() {
        launchApp()
        openGroup("Sunday Legends")
        let detail = GroupDetailScreen(app: app)
        waitFor(detail.gamesTab, timeout: 15).tap()

        // FRANCE appears ONLY on the live game card (the GAMES tab auto-scrolls to
        // the next-upcoming day group, which contains it).
        let board = LiveScoreboardScreen(app: app)
        scrollTo(board.team("France"))
        waitFor(board.team("Spain"), timeout: 5)

        waitForWebSocketClient()
        withScenario { scenario in
            scenario.updateGame(DefaultScenario.liveGameID) { game in
                game.homeTeamScore = 4
                game.awayTeamScore = 3
            }
        }
        pushWS(type: "evaluate_game",
               message: LiveWire.evaluateGame(gameID: DefaultScenario.liveGameID, home: 4, away: 3))

        // Details reload ONLY on the WS event (the 10 s poll covers bets, not details).
        waitFor(board.scoreDigit(4), timeout: 15)
        waitFor(board.scoreDigit(3), timeout: 5)
    }

    /// `bet_placed` bumps the coordinator's bet-activity counter: Home re-derives the
    /// need-action section, so betting server-side flips the urgent banner to the
    /// plain "Todays games" panel without any user refresh.
    func testBetPlacedEventRefreshesHomeNeedActionSection() {
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(TabBarScreen(app: app).home, timeout: 20)
        waitFor(home.navigationBar, timeout: 15)

        let urgentHeader = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "make sure to bet")).firstMatch
        scrollTo(urgentHeader)

        waitForWebSocketClient()
        withScenario { scenario in
            // The upcoming game is deliberately un-bet in BOTH running groups.
            scenario.upsertBet(userID: DefaultScenario.currentUserID,
                               gameID: DefaultScenario.upcomingGameID,
                               groupID: DefaultScenario.groupSundayLegendsID, home: 2, away: 1)
            scenario.upsertBet(userID: DefaultScenario.currentUserID,
                               gameID: DefaultScenario.upcomingGameID,
                               groupID: DefaultScenario.groupOfficeRoyaleID, home: 2, away: 1)
        }
        pushWS(type: "bet_placed", message: LiveWire.bet(
            userID: DefaultScenario.currentUserID,
            gameID: DefaultScenario.upcomingGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            home: 2, away: 1, isUniversal: true))

        waitForDisappearance(urgentHeader, timeout: 15)
        waitFor(app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "todays games")).firstMatch,
                timeout: 10)
    }

    // MARK: - Chat (no message events exist on the wire — 10 s poll) + live ticker

    /// A server-side chat message surfaces through the 10 s message-board poll (the
    /// wire has NO message events), and the chat screen's ACTIVITY segment ticks live
    /// WS events.
    func testChatPollPicksUpServerMessageAndActivitySegmentTicks() {
        launchApp()
        openGroup("Sunday Legends")
        scrollTo(app.buttons["OPEN MEME BOARD →"], maxSwipes: 10).tap()

        let chat = GroupChatScreen(app: app)
        waitFor(chat.message(containing: "Bring on the weekend!"), timeout: 15)

        withScenario { scenario in
            scenario.addServerSideMessage(id: 501,
                                          groupID: DefaultScenario.groupSundayLegendsID,
                                          userID: DefaultScenario.friendUserID,
                                          body: "Server-side scoop")
        }
        // Next poll tick is at most 10 s away.
        waitFor(chat.message(containing: "Server-side scoop"), timeout: 20)

        waitForWebSocketClient()
        app.buttons["ACTIVITY"].firstMatch.tap()
        pushWS(type: "group_joined", message: LiveWire.groupJoined(
            groupID: DefaultScenario.groupPublicID, name: "Open Arena", who: "Robin Rival"))
        waitFor(staticText(containing: "Robin Rival just joined Open Arena"), timeout: 15)
    }

    // MARK: - Activity feed event rendering (screens §3.8)

    /// Membership + registration events render their styled rows; the feed starts
    /// empty (live only — the /activitystream backfill stub returns []).
    func testActivityFeedRendersMembershipAndRegistrationEvents() {
        launchApp()
        let activity = openActivityTab()
        waitFor(activity.emptyStateTitle, timeout: 10)

        waitForWebSocketClient()
        pushWS(type: "group_joined", message: LiveWire.groupJoined(
            groupID: DefaultScenario.groupSundayLegendsID, name: "Sunday Legends", who: "Casey Friend"))
        waitFor(activity.row(containing: "Casey Friend just joined Sunday Legends"), timeout: 15)
        waitFor(staticText(containing: "JOINED GROUP"), timeout: 5)

        // Empty `who` falls back to "Someone" (web `||` semantics).
        pushWS(type: "group_joined", message: LiveWire.groupJoined(
            groupID: DefaultScenario.groupPublicID, name: "Open Arena", who: nil))
        waitFor(activity.row(containing: "Someone just joined Open Arena"), timeout: 15)

        pushWS(type: "group_left")
        waitFor(activity.row(containing: "Someone just left a group"), timeout: 15)

        pushWS(type: "group_created")
        waitFor(activity.row(containing: "New group on Betty"), timeout: 15)

        pushWS(type: "user_register",
               message: LiveWire.user(id: "uid-new", email: "zoe@betty.test", name: "Zoe Newcomer"))
        waitFor(activity.row(containing: "Zoe Newcomer just joined Betty"), timeout: 15)
        waitFor(staticText(containing: "★ WELCOME"), timeout: 5)
    }

    /// Exact-score / visibility / unknown event rows, then CLEAR ALL empties the feed.
    func testActivityFeedRendersScoreVisibilityUnknownEventsAndClearAll() {
        launchApp()
        let activity = openActivityTab()
        waitForWebSocketClient()

        // Signed-in user among the exact scorers → "You and N other(s)".
        pushWS(type: "user_exact_score", message: [
            "game_id": DefaultScenario.finishedGameID,
            "user_ids": [DefaultScenario.currentUserID, DefaultScenario.friendUserID],
        ])
        waitFor(activity.row(containing: "You and 1 other(s) had the exact score"), timeout: 15)
        waitFor(staticText(containing: "EXACT SCORE"), timeout: 5)

        pushWS(type: "user_exact_score", message: [
            "game_id": DefaultScenario.finishedGameID,
            "user_ids": [DefaultScenario.friendUserID, DefaultScenario.rivalUserID],
        ])
        waitFor(activity.row(containing: "2 players had the exact score!"), timeout: 15)

        // Known group resolves its cached name; public_at set reads "public".
        pushWS(type: "group_visibility_changed", message: [
            "group_id": DefaultScenario.groupSundayLegendsID,
            "public_at": LiveWire.iso(Date()),
        ])
        waitFor(activity.row(containing: "Sunday Legends is now public"), timeout: 15)

        // Unknown group falls back to "A group"; null public_at reads "private".
        pushWS(type: "group_visibility_changed", message: [
            "group_id": 999,
            "public_at": NSNull(),
        ])
        waitFor(activity.row(containing: "A group is now private"), timeout: 15)

        // Unknown event types still render generically (raw type uppercased).
        pushWS(type: "mystery_event", message: ["anything": 1])
        waitFor(activity.row(containing: "MYSTERY_EVENT"), timeout: 15)

        waitFor(activity.clearAllButton, timeout: 5).tap()
        waitFor(activity.emptyStateTitle, timeout: 10)
    }

    /// `evaluate_game` renders the "FULL TIME / Game evaluated" row with the game's
    /// final score (lazily fetched via GET /game/:id when not cached).
    func testEvaluateGameEventRendersFullTimeRowWithFinalScore() {
        launchApp()
        let activity = openActivityTab()
        waitForWebSocketClient()

        withScenario { scenario in
            scenario.updateGame(DefaultScenario.liveGameID) { game in
                game.homeTeamScore = 4
                game.awayTeamScore = 3
                game.status = 1
            }
        }
        pushWS(type: "evaluate_game",
               message: LiveWire.evaluateGame(gameID: DefaultScenario.liveGameID, home: 4, away: 3))

        waitFor(staticText(containing: "FULL TIME"), timeout: 15)
        waitFor(activity.row(containing: "Game evaluated"), timeout: 5)
        waitFor(app.staticTexts["4 - 3"].firstMatch, timeout: 10)
    }

    /// `game_starting_soon` decodes the capital-G `"Games"` key (Go struct field
    /// without a json tag) and renders the kickoff row.
    func testGameStartingSoonEventUsesCapitalGamesKey() {
        launchApp()
        let activity = openActivityTab()
        waitForWebSocketClient()

        pushWS(type: "game_starting_soon", message: LiveWire.gameStartingSoon(
            gameID: DefaultScenario.upcomingGameID,
            startDate: Date().addingTimeInterval(900)))
        waitFor(activity.row(containing: "Match is about to start"), timeout: 15)
        waitFor(staticText(containing: "KICKING OFF"), timeout: 5)
    }

    /// `bet_placed` / `bet_updated` render the NEW BET / BET UPDATED rows (game data
    /// loaded lazily so the matchup shows even when the game wasn't cached).
    func testBetEventsRenderActivityRows() {
        launchApp()
        let activity = openActivityTab()
        waitForWebSocketClient()

        pushWS(type: "bet_placed", message: LiveWire.bet(
            userID: DefaultScenario.friendUserID,
            gameID: DefaultScenario.liveGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            home: 1, away: 1))
        waitFor(activity.row(containing: "Someone placed a bet on"), timeout: 15)
        waitFor(staticText(containing: "NEW BET"), timeout: 5)

        pushWS(type: "bet_updated", message: LiveWire.bet(
            userID: DefaultScenario.friendUserID,
            gameID: DefaultScenario.liveGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            home: 2, away: 2, id: 77))
        waitFor(activity.row(containing: "Someone updated their bet on"), timeout: 15)
        waitFor(staticText(containing: "BET UPDATED"), timeout: 5)
    }

    // MARK: - Toast / notify patterns (data-layer §12)

    /// A failed bets poll raises the pinned warning toast (HEADS UP) once; the X
    /// button dismisses it manually.
    func testBetsPollFailureShowsWarningToastWithManualDismiss() {
        launchApp()
        openGroup("Sunday Legends")
        let detail = GroupDetailScreen(app: app)
        waitFor(detail.groupTab, timeout: 15)

        // Registered AFTER the first successful load, so only the NEXT 10 s poll
        // iteration fails (Home and the detail screen rendered normally).
        backend.http.route("GET", "/api/v1/bets/bygroup/:group") { _, _ in .empty(500) }

        let toast = LiveToastScreen(app: app)
        waitFor(toast.text(containing: "Could not load bets"), timeout: 25)
        waitFor(toast.kicker("HEADS UP"), timeout: 5)
        XCTAssertTrue(toast.text(containing: "Please refresh to make sure all bets are loaded.").exists)

        waitFor(toast.dismissButton, timeout: 5).tap()
        // Gone well before the 4 s auto-dismiss would fire — this was the manual path.
        waitForDisappearance(toast.text(containing: "Could not load bets"), timeout: 2)
    }

    /// Success alerts show the NICE kicker and auto-dismiss after ~4 s with no
    /// interaction.
    func testNicknameSaveShowsSuccessToastThatAutoDismisses() {
        launchApp()
        openGroup("Sunday Legends")

        let field = app.textFields["Your nickname"]
        scrollTo(field, maxSwipes: 10)
        field.tap()
        field.typeText("Lightning")
        app.buttons["SAVE"].firstMatch.tap()

        let toast = LiveToastScreen(app: app)
        waitFor(toast.text(containing: "Nickname updated."), timeout: 10)
        waitFor(toast.kicker("NICE"), timeout: 5)
        waitForDisappearance(toast.text(containing: "Nickname updated."), timeout: 8)
    }

    /// Confirm toasts never auto-dismiss; CANCEL drops them without running the
    /// destructive action.
    func testLeaveGroupConfirmPersistsAndCancelAborts() {
        launchApp()
        openGroup("Office Royale")
        scrollTo(app.buttons["LEAVE GROUP"], maxSwipes: 12).tap()

        let toast = LiveToastScreen(app: app)
        let question = toast.text(containing: "Are you sure you want to leave Office Royale?")
        waitFor(question, timeout: 10)
        waitFor(toast.kicker("HEADS UP"), timeout: 5)
        waitFor(toast.cancelButton, timeout: 5)
        waitFor(toast.confirmButton, timeout: 5)

        // Outlive the 4 s alert auto-dismiss window.
        let vanished = XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                            object: question)],
            timeout: 5.5)
        XCTAssertNotEqual(vanished, .completed, "Confirm toasts must not auto-dismiss")

        toast.cancelButton.tap()
        waitForDisappearance(question, timeout: 5)
        XCTAssertTrue(
            backend.requests(method: "DELETE",
                             pathPrefix: "/api/v1/group/\(DefaultScenario.groupOfficeRoyaleID)/leave").isEmpty,
            "CANCEL must not issue the leave request")
    }

    /// Accepting a confirm runs the action; a failed leave surfaces the OOPS error
    /// toast (and the confirm card itself dismisses after accept).
    func testLeaveGroupFailureShowsErrorToastAfterConfirmAccept() {
        backend.http.route("DELETE", "/api/v1/group/:id/leave") { _, _ in .empty(500) }
        launchApp()
        openGroup("Office Royale")
        scrollTo(app.buttons["LEAVE GROUP"], maxSwipes: 12).tap()

        let toast = LiveToastScreen(app: app)
        waitFor(toast.confirmButton, timeout: 10).tap()

        waitFor(toast.text(containing: "Could not leave group"), timeout: 10)
        waitFor(toast.kicker("OOPS"), timeout: 5)
        XCTAssertEqual(
            backend.requests(method: "DELETE",
                             pathPrefix: "/api/v1/group/\(DefaultScenario.groupOfficeRoyaleID)/leave").count,
            1, "Accepting the confirm must issue exactly one leave request")
    }
}
