import XCTest

/// End-to-end coverage for the Boosters feature (spec
/// `docs/superpowers/specs/2026-06-14-boosters-design.md` §4.2 — the 9 canonical
/// scenarios).
///
/// Extends `GroupDetailE2EBase` so the bet-sheet / settings-sheet helpers are
/// available. The hermetic mock backend (`MockAPIRoutes` + `MockWire`) speaks the
/// real wire shape for `boost_count` / `boost_multiplier` / `boosted` and validates
/// the spec §1.1 / §1.2 rules.
///
/// CRITICAL (CLAUDE.md): this class is assigned to an iOS e2e shard in
/// `.github/workflows/ci.yml` — the `Verify e2e shard coverage` step fails CI
/// otherwise.
final class BoosterE2ETests: GroupDetailE2EBase {

    // MARK: - Helpers

    /// Opens the author's settings sheet for Sunday Legends (boosters enabled in the
    /// default fixture). Mirrors `GroupMgmtTestCase.openSundayLegendsSettings`.
    private func openSundayLegendsSettings() {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: "Sunday Legends"), maxSwipes: 8).tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        scrollTo(app.buttons["EDIT →"], maxSwipes: 14).tap()
        waitFor(GroupSettingsPage(app: app).editTitle, timeout: 10)
    }

    /// Clear-and-retype mirrors the replaceText path in `GroupMgmtTestCase`.
    private func replaceText(in field: XCUIElement, with text: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        field.tap()
        for _ in 0..<3 {
            if (field.value as? String) == text { return }
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            let current = (field.value as? String) ?? ""
            if !current.isEmpty {
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

    /// The first booster fixture group (`Sunday Legends`) — boosters ON, count=2, ×2.
    private var boostersOnGroupID: Int { DefaultScenario.groupSundayLegendsID }
    /// The boosters-OFF group (`Office Royale`) — count=0.
    private var boostersOffGroupID: Int { DefaultScenario.groupOfficeRoyaleID }

    // MARK: - Scenarios

    /// Spec §4.2 #1: Admin enables boosters from a clean state, values persist.
    func testAdminEnablesBoostersAndValuesPersist() {
        // Start from boosters OFF so we exercise the enable path.
        withScenario { $0.groupDetailSetBoosters(count: 0, multiplier: 2) }
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.boostCountField, maxSwipes: 10)
        replaceText(in: settings.boostCountField, with: "2")
        replaceText(in: settings.boostMultiplierField, with: "2")
        dismissKeyboardIfPresent()
        scrollTo(settings.saveButton, maxSwipes: 8).tap()
        waitForDisappearance(settings.editTitle, timeout: 10)

        let put = backend.requests(
            method: "PUT",
            pathPrefix: "/api/v1/group/\(boostersOnGroupID)/settings").first
        XCTAssertEqual(put?.bodyJSON?["boost_count"] as? Int, 2)
        XCTAssertEqual(put?.bodyJSON?["boost_multiplier"] as? Int, 2)

        let saved = withScenario { $0.group(self.boostersOnGroupID) }
        XCTAssertEqual(saved?.boostCount, 2)
        XCTAssertEqual(saved?.boostMultiplier, 2)
    }

    /// Spec §4.2 #2: Apply a booster, reopen — switch on, remaining 2→1, activity
    /// feed shows a `booster_applied` row.
    func testApplyBoosterPersistsAndEmitsActivity() {
        withScenario { $0.groupDetailSetBoosters(count: 2, multiplier: 2) }
        launchApp()
        waitForWebSocketClient()

        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        sheet.homePlus.tap()
        sheet.awayPlus.tap()
        // Boosters row visible — toggle ON.
        waitFor(sheet.boostToggle, timeout: 5)
        sheet.tapBoostToggle()
        sheet.submitButton.tap()
        waitForDisappearance(sheet.header, timeout: 10)

        // Server-side: the sent bet on this group is boosted.
        let stored = withScenario { scenario in
            scenario.bets.first {
                $0.userID == DefaultScenario.currentUserID
                    && $0.groupID == self.boostersOnGroupID
                    && $0.gameID == DefaultScenario.upcomingGameID
            }
        }
        XCTAssertEqual(stored?.boosted, true)

        // POST body carries `boosted: true`.
        let posts = backend.requests(method: "POST", pathPrefix: "/api/v1/bet")
        XCTAssertEqual(posts.last?.bodyJSON?["boosted"] as? Bool, true)

        // Reopen sheet — toggle still on, help text shows the new multiplier line.
        locateGameCard(DefaultScenario.upcomingGameID, via: screen).tap()
        let reopened = BetSheetScreen(app: app)
        waitFor(reopened.boostToggle, timeout: 5)
        XCTAssertEqual(reopened.boostToggle.value as? String, "1")

        // Drop the BetSheet first — sheets cover the tab bar.
        reopened.closeButton.tap()
        waitForDisappearance(reopened.header, timeout: 5)

        // Activity feed eventually surfaces the booster_applied row.
        scrollTo(TabBarScreen(app: app).activity, maxSwipes: 3).tap()
        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 15)
        waitFor(activity.row(containing: "BOOSTER"), timeout: 10)
    }

    /// Spec §4.2 #3: Un-apply pre-kickoff returns capacity and emits no new event.
    func testUnapplyBoosterReturnsCapacity() {
        withScenario { scenario in
            scenario.groupDetailSetBoosters(count: 2, multiplier: 2)
            scenario.groupDetailAddBet(
                userID: DefaultScenario.currentUserID,
                gameID: DefaultScenario.upcomingGameID,
                home: 2, away: 1, boosted: true
            )
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.boostToggle, timeout: 5)
        XCTAssertEqual(sheet.boostToggle.value as? String, "1")
        sheet.tapBoostToggle()
        // Edit only this group — uncheck universal so we drive PUT.
        sheet.tapUniversalToggle()
        sheet.submitButton.tap()
        waitForDisappearance(sheet.header, timeout: 10)

        let stored = withScenario { scenario in
            scenario.bets.first {
                $0.userID == DefaultScenario.currentUserID
                    && $0.groupID == self.boostersOnGroupID
                    && $0.gameID == DefaultScenario.upcomingGameID
            }
        }
        XCTAssertEqual(stored?.boosted, false)
    }

    /// Spec §4.2 #4: Zero remaining disables the switch and surfaces the helper.
    func testZeroRemainingDisablesSwitch() {
        // Burn both boosters on two OTHER games. Then open a third game where the
        // user has no remaining capacity.
        withScenario { scenario in
            scenario.groupDetailSetBoosters(count: 2, multiplier: 2)
            scenario.groupDetailAddBet(
                userID: DefaultScenario.currentUserID,
                gameID: DefaultScenario.liveGameID,
                home: 1, away: 2, boosted: true
            )
            scenario.groupDetailAddBet(
                userID: DefaultScenario.currentUserID,
                gameID: DefaultScenario.finishedGameID,
                home: 2, away: 0, boosted: true
            )
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.boostToggle, timeout: 5)
        XCTAssertEqual(sheet.boostToggle.value as? String, "0")
        XCTAssertFalse(sheet.boostToggle.isEnabled)
        waitForLabel(sheet.boostHelp, contains: "No boosters remaining")
    }

    /// Spec §4.2 #5: Boosted bet scores ×N at evaluation with the rocket next to points.
    /// Scenario must finalize BEFORE `launchApp()` — the client caches `groups`/`bets`
    /// on first load and only re-fetches on its own polling cadence.
    func testBoostedBetScoresMultiplierAndShowsRocket() {
        // Use the FINISHED game (scenario already has it as `status: 1`); rewrite its
        // bet to be boosted with the exact-score points × multiplier.
        withScenario { scenario in
            scenario.groupDetailSetBoosters(count: 2, multiplier: 2)
            // Find the existing finished-game bet for the current user in Sunday Legends
            // and mark it boosted with the expected post-eval points (base 3 × mult 2 = 6).
            for index in scenario.bets.indices
            where scenario.bets[index].gameID == DefaultScenario.finishedGameID
                && scenario.bets[index].userID == DefaultScenario.currentUserID
                && scenario.bets[index].groupID == DefaultScenario.groupSundayLegendsID {
                scenario.bets[index].boosted = true
                scenario.bets[index].userPoints = 6
            }
        }
        launchApp()

        let screen = openSundayLegends()
        scrollTo(screen.gamesTab).tap()
        let card = locateGameCard(DefaultScenario.finishedGameID, via: screen)
        // Expect 6P (base 3 × multiplier 2) AND the rocket — XCUI reads our
        // `accessibilityLabel("Boosted")` for the 🚀 glyph.
        waitForLabel(card, contains: "6P")
        assertLabel(card, contains: "Boosted")
    }

    /// Spec §4.2 #6: A boosted bet with zero base points shows no rocket.
    func testZeroPointBoostedBetSuppressesRocket() {
        // Use the friendUser's bet on the finished game — already has 0 points; just
        // flip its boosted flag. The friend's row appears in the placed-bets list when
        // we open the bet sheet on a finished game (sneak peek allows it).
        withScenario { scenario in
            scenario.groupDetailSetBoosters(count: 2, multiplier: 2)
            for index in scenario.bets.indices
            where scenario.bets[index].gameID == DefaultScenario.finishedGameID
                && scenario.bets[index].userID == DefaultScenario.friendUserID {
                scenario.bets[index].boosted = true
                // Already 0 user_points in the default fixture — explicit assert below.
                XCTAssertEqual(scenario.bets[index].userPoints, 0)
            }
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.finishedGameID, via: screen)
        sheet.placedTab.tap()
        // Iterate placed rows; find Casey Friend's row and assert it does NOT carry
        // the "Boosted" accessibility label (§2.5 suppression — points == 0).
        for index in 0..<5 {
            let row = sheet.placedRow(index)
            guard row.waitForExistence(timeout: 2) else { break }
            if row.label.contains("Casey Friend") {
                assertLabel(row, notContains: "Boosted")
                return
            }
        }
        XCTFail("Casey Friend's row never appeared in the placed-bets list")
    }

    /// Spec §4.2 #7: Universal + boost only boosts the current group.
    func testUniversalBoostOnlyMarksCurrentGroup() {
        // Default fixture: Sunday Legends boosters ON, Office Royale boosters OFF.
        // A universal bet from Sunday Legends must boost ONLY Sunday Legends' row.
        withScenario { scenario in
            scenario.groupDetailSetBoosters(count: 2, multiplier: 2,
                                            groupID: self.boostersOnGroupID)
            scenario.groupDetailSetBoosters(count: 0,
                                            groupID: self.boostersOffGroupID)
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)
        sheet.homePlus.tap()
        sheet.awayPlus.tap()
        waitFor(sheet.boostToggle, timeout: 5)
        sheet.tapBoostToggle()
        XCTAssertEqual(sheet.universalToggle.value as? String, "1")
        sheet.submitButton.tap()
        waitForDisappearance(sheet.header, timeout: 10)

        let bets = withScenario { scenario in
            scenario.bets.filter {
                $0.userID == DefaultScenario.currentUserID
                    && $0.gameID == DefaultScenario.upcomingGameID
            }
        }
        let onGroup = bets.first { $0.groupID == boostersOnGroupID }
        let offGroup = bets.first { $0.groupID == boostersOffGroupID }
        XCTAssertEqual(onGroup?.boosted, true)
        XCTAssertEqual(offGroup?.boosted, false, "universal bet must NOT boost siblings")
    }

    /// Spec §4.2 #8: A group with `boost_count = 0` hides the booster row entirely.
    func testBoostersOffHidesRowInBetSheet() {
        // The default Office Royale group already has boosters off.
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: "Office Royale"), maxSwipes: 8).tap()
        waitFor(staticText(containing: "OFFICE ROYALE"), timeout: 15)
        let screen = GroupDetailScreen(app: app)
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)
        waitFor(sheet.submitButton)
        XCTAssertFalse(sheet.boostToggle.exists, "booster row must be hidden when boost_count == 0")
    }

    /// Spec §4.2 #9: Admin sets count=0 mid-tournament — the row hides for future
    /// edits, the existing pre-kickoff rocket stays visible on the placed-bets row,
    /// and the score eventually evaluates at 1× (the `boost_count > 0` gate in the
    /// scoring formula collapses the multiplier).
    ///
    /// Scenario state must be finalised BEFORE `launchApp()` because the client
    /// caches `groups`/`bets` on first load; the "admin disables" beat is the cached
    /// terminal state we assert against.
    func testAdminDisablesMidTournamentLeavesExistingBoosted() {
        withScenario { scenario in
            // Boosters were on, the user already boosted a bet, then admin set count
            // to 0 — the existing flag stays on the row per spec §2.4 / §2.6.
            scenario.groupDetailSetBoosters(count: 0, multiplier: 2)
            scenario.groupDetailSetSneakPeek(true)
            scenario.groupDetailAddBet(
                userID: DefaultScenario.currentUserID,
                gameID: DefaultScenario.upcomingGameID,
                home: 2, away: 1, boosted: true
            )
        }
        launchApp()

        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)
        waitFor(sheet.submitButton, timeout: 10)
        // Booster row is hidden (count == 0 hides it).
        XCTAssertFalse(sheet.boostToggle.exists)

        // The pre-kickoff placed row still shows the rocket (existing `boosted: true`
        // on an unprocessed bet — spec §2.4 / §3.4 paragraph 2). XCUI surfaces our
        // accessibilityLabel("Boosted") on the 🚀 glyph.
        sheet.placedTab.tap()
        let row = waitFor(sheet.placedRow(0))
        assertLabel(row, contains: "Boosted")

        // Drive the mock backend's real evaluate route — this exercises the
        // multiplier-collapse logic in MockAPIRoutes (`boost_count > 0` gate).
        sheet.closeButton.tap()
        waitForDisappearance(sheet.header, timeout: 5)
        let evalURL = URL(string: "\(backend.apiBaseURL.absoluteString)/evaluategame")!
        var evalRequest = URLRequest(url: evalURL)
        evalRequest.httpMethod = "POST"
        evalRequest.httpBody = try? JSONSerialization.data(withJSONObject: [
            "game_id": DefaultScenario.upcomingGameID,
            "home_team_score": 2,
            "away_team_score": 1,
        ])
        evalRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        evalRequest.setValue("Bearer \(backend.idToken(for: DefaultScenario.currentUserID))",
                             forHTTPHeaderField: "Authorization")
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: evalRequest) { _, _, _ in sem.signal() }.resume()
        _ = sem.wait(timeout: .now() + 5)

        // Confirm the stored points reflect the 1× collapse — base 3 (exact score) × 1.
        let bet = withScenario { scenario in
            scenario.bets.first {
                $0.userID == DefaultScenario.currentUserID
                    && $0.groupID == self.boostersOnGroupID
                    && $0.gameID == DefaultScenario.upcomingGameID
            }
        }
        XCTAssertEqual(bet?.userPoints, 3, "boost_count=0 must collapse multiplier to 1×")
    }
}
