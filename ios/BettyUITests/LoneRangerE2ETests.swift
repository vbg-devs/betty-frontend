import XCTest

/// End-to-end coverage for the Lone Ranger bonus (spec
/// `docs/superpowers/specs/2026-06-20-lone-ranger-design.md` §7.2 — the 6 canonical
/// scenarios).
///
/// Extends `GroupDetailE2EBase` so the settings-sheet / bet-sheet / activity helpers
/// are available. The hermetic mock backend (`MockAPIRoutes` + `MockWire`) speaks the
/// real wire shape for `lone_ranger_enabled` / `lone_ranger_points`, replicates the
/// two-pass evaluate tally (draws excluded), and emits the `lone_ranger_awarded` WS
/// frame when at least one bonus is awarded.
///
/// CRITICAL (CLAUDE.md): this class is assigned to an iOS e2e shard in
/// `.github/workflows/ci.yml` — the `Verify e2e shard coverage` step fails CI
/// otherwise.
final class LoneRangerE2ETests: GroupDetailE2EBase {

    /// Sunday Legends — current user (Alex) is AUTHOR; used for the settings scenario.
    private var groupID: Int { DefaultScenario.groupSundayLegendsID }

    // MARK: - Helpers

    /// Opens the author's settings sheet for Sunday Legends. Mirrors the Booster suite.
    private func openSundayLegendsSettings() {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: "Sunday Legends"), maxSwipes: 8).tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        scrollTo(app.buttons["EDIT →"], maxSwipes: 14).tap()
        waitFor(GroupSettingsPage(app: app).editTitle, timeout: 10)
    }

    /// Clear-and-retype mirrors the replaceText path in the Booster suite.
    private func replaceText(in field: XCUIElement, with text: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        // A numberPad TextField gated behind a just-flipped toggle can miss focus on the
        // first tap (the keyboard isn't already up, unlike when editing a sibling text
        // field). Tap until the keyboard actually appears, then type.
        for _ in 0..<4 {
            if (field.value as? String) == text { return }
            field.tap()
            if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
                // Retry with a center-coordinate tap if the element tap didn't focus.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
            }
            let current = (field.value as? String) ?? ""
            if !current.isEmpty, current != "0" {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1))
            }
            field.typeText(text)
            if (field.value as? String) == text { return }
        }
        XCTAssertEqual(field.value as? String, text,
                       "replaceText never settled on the new value", file: file, line: line)
    }

    private func tapToggle(_ toggle: XCUIElement) {
        let control = toggle.switches.firstMatch
        if control.exists, control.isHittable {
            control.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }

    /// Drives the mock backend's real `/evaluategame` route (synchronously). This is the
    /// path that runs the two-pass tally and emits the `lone_ranger_awarded` frame.
    @discardableResult
    private func evaluate(gameID: Int, home: Int, away: Int) -> Bool {
        let evalURL = URL(string: "\(backend.apiBaseURL.absoluteString)/evaluategame")!
        var request = URLRequest(url: evalURL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "game_id": gameID,
            "home_team_score": home,
            "away_team_score": away,
        ])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(backend.idToken(for: DefaultScenario.adminUserID))",
                         forHTTPHeaderField: "Authorization")
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse { ok = (200...299).contains(http.statusCode) }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 8)
        return ok
    }

    private func points(userID: String, gameID: Int) -> Int? {
        withScenario { scenario in
            scenario.bets.first { $0.userID == userID && $0.gameID == gameID && $0.groupID == self.groupID }?.userPoints
        }
    }

    // MARK: - Scenario 1: admin enables, persists, points disabled when off

    func testAdminEnablesLoneRangerAndValuesPersist() {
        // Start OFF so we exercise the enable path.
        withScenario { $0.groupDetailSetLoneRanger(enabled: false, points: 0) }
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        // Points field is disabled while the toggle is OFF.
        scrollTo(settings.loneRangerToggle, maxSwipes: 12)
        XCTAssertFalse(settings.loneRangerPointsField.isEnabled,
                       "points input must be disabled when Lone Ranger is off")

        // Enable and set N = 5.
        tapToggle(settings.loneRangerToggle)
        // Wait until the toggle flip enables the points field before typing.
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: settings.loneRangerPointsField)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 5), .completed,
                       "points input should become enabled after toggling Lone Ranger on")
        scrollTo(settings.loneRangerPointsField, maxSwipes: 6)
        replaceText(in: settings.loneRangerPointsField, with: "5")
        dismissKeyboardIfPresent()
        scrollTo(settings.saveButton, maxSwipes: 8).tap()
        waitForDisappearance(settings.editTitle, timeout: 10)

        // PUT body carries both fields.
        let put = backend.requests(method: "PUT",
                                   pathPrefix: "/api/v1/group/\(groupID)/settings").first
        XCTAssertEqual(put?.bodyJSON?["lone_ranger_enabled"] as? Bool, true)
        XCTAssertEqual(put?.bodyJSON?["lone_ranger_points"] as? Int, 5)

        // Server-side persisted.
        let saved = withScenario { $0.group(self.groupID) }
        XCTAssertEqual(saved?.loneRangerEnabled, true)
        XCTAssertEqual(saved?.loneRangerPoints, 5)
    }

    // MARK: - Scenario 2: lone correct predictor gets base + N

    func testLoneCorrectPredictorGetsBonus() {
        // Sunday Legends: lone ranger ON, N=5, correct_team_points=1 (default fixture).
        // Two members bet on the upcoming game; only Alex predicts the winning side.
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: true, points: 5)
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1) // home win predicted
            scenario.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 0, away: 2) // away predicted (wrong)
        }
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 0)) // home wins

        // Alex: base 1 (correct team) + 5 bonus = 6. Casey: wrong side → 0.
        XCTAssertEqual(points(userID: DefaultScenario.currentUserID, gameID: DefaultScenario.upcomingGameID), 6)
        XCTAssertEqual(points(userID: DefaultScenario.friendUserID, gameID: DefaultScenario.upcomingGameID), 0)
    }

    // MARK: - Scenario 3: two correct predictors → no bonus

    func testTwoCorrectPredictorsGetNoBonus() {
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: true, points: 5)
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1)
            scenario.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 3, away: 0)
        }
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 0))

        // Both called home → count == 2 → neither gets +5; both get base 1.
        XCTAssertEqual(points(userID: DefaultScenario.currentUserID, gameID: DefaultScenario.upcomingGameID), 1)
        XCTAssertEqual(points(userID: DefaultScenario.friendUserID, gameID: DefaultScenario.upcomingGameID), 1)
    }

    // MARK: - Scenario 4: draw → no bonus

    func testDrawAwardsNoBonus() {
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: true, points: 5)
            // The sole member who "called the draw".
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 1, away: 1)
        }
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 1)) // draw

        // Draw → no winning side → exact-score points (base exact 3) but NO lone bonus.
        XCTAssertEqual(points(userID: DefaultScenario.currentUserID, gameID: DefaultScenario.upcomingGameID), 3)
    }

    // MARK: - Scenario 5: feature off → no bonus

    func testFeatureOffAwardsNoBonus() {
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: false, points: 5)
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1)
            scenario.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 0, away: 2)
        }
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 0))

        // Feature off → lone correct predictor gets base 1 only.
        XCTAssertEqual(points(userID: DefaultScenario.currentUserID, gameID: DefaultScenario.upcomingGameID), 1)
    }

    // MARK: - Scenario 6: celebratory badge

    /// The lone winner (signed-in Alex) sees the you-variant feed item, driven by the
    /// real mock `lone_ranger_awarded` frame from `/evaluategame`.
    func testBadgeAppearsForLoneWinner() {
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: true, points: 5)
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1)
            scenario.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 0, away: 2)
        }
        launchApp()
        waitForWebSocketClient()

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 0))

        scrollTo(TabBarScreen(app: app).activity, maxSwipes: 3).tap()
        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 15)
        waitFor(activity.row(containing: "LONE RANGER"), timeout: 10)
        // You-variant copy for the signed-in winner.
        waitFor(activity.row(containing: "You were the Lone Ranger"), timeout: 10)
    }

    /// A non-winner sees the count-variant copy. The signed-in user (Alex) is NOT in the
    /// pushed `user_ids`, so the feed renders the "N player(s)" variant.
    func testBadgeShowsCountVariantForNonWinner() {
        launchApp()
        waitForWebSocketClient()
        pushWS(type: "lone_ranger_awarded",
               message: ["game_id": DefaultScenario.finishedGameID,
                         "user_ids": [DefaultScenario.friendUserID]])

        scrollTo(TabBarScreen(app: app).activity, maxSwipes: 3).tap()
        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 15)
        // The meta header "🤠 LONE RANGER" is present; assert the BODY copy is the
        // count-variant and NOT the you-variant.
        waitFor(activity.row(containing: "LONE RANGER"), timeout: 10)
        XCTAssertTrue(activity.row(containing: "player(s) were the Lone Ranger").waitForExistence(timeout: 5),
                      "non-winner must see the count-variant copy")
        XCTAssertFalse(activity.row(containing: "You were the Lone Ranger").exists,
                       "non-winner must NOT see the you-variant copy")
    }

    /// No badge in the two-correct, draw, and feature-off cases (the frame is never
    /// emitted when no bonus is awarded).
    func testNoBadgeWhenNoBonusAwarded() {
        withScenario { scenario in
            scenario.groupDetailSetLoneRanger(enabled: true, points: 5)
            // Two correct predictors → no bonus → no frame.
            scenario.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 2, away: 1)
            scenario.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                       gameID: DefaultScenario.upcomingGameID, home: 3, away: 0)
        }
        launchApp()
        waitForWebSocketClient()

        XCTAssertTrue(evaluate(gameID: DefaultScenario.upcomingGameID, home: 1, away: 0))

        scrollTo(TabBarScreen(app: app).activity, maxSwipes: 3).tap()
        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 15)
        // Give the feed a moment to settle, then assert NO lone-ranger row exists.
        XCTAssertFalse(activity.row(containing: "LONE RANGER").waitForExistence(timeout: 4),
                       "no lone_ranger_awarded badge should appear when no bonus is awarded")
    }
}
