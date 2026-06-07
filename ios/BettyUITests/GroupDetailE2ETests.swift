import XCTest

/// End-to-end coverage for the group-detail area: hero stats, dense tie-ranked
/// leaderboard + TOP 3 / final podium, the day-grouped games schedule with
/// upcoming/live/finished row states, bet placement & editing through the BetSheet
/// (incl. the universal-edit POST pin and the 423 "betting closed" path), the
/// sneak-peek/HiddenScore rules, and member bet-history sheets.
final class GroupDetailE2ETests: BettyUITestCase {

    // MARK: - Shared flows

    /// Home → tap a group card → group detail (hero shows the uppercased name).
    @discardableResult
    private func openGroup(named name: String, ended: Bool = false) -> GroupDetailScreen {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        if ended {
            waitFor(home.endedTab).tap()
        }
        scrollTo(home.groupCard(named: name)).tap()
        waitFor(staticText(containing: name.uppercased()), timeout: 15)
        return GroupDetailScreen(app: app)
    }

    @discardableResult
    private func openSundayLegends() -> GroupDetailScreen {
        openGroup(named: "Sunday Legends")
    }

    /// Finds a schedule card searching BOTH directions — the Games tab auto-anchors
    /// to the next-upcoming day, so earlier days sit above the viewport.
    @discardableResult
    private func locateGameCard(_ gameID: Int, via screen: GroupDetailScreen,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let card = screen.gameCard(gameID)
        if card.waitForExistence(timeout: 3), card.isHittable { return card }
        for _ in 0..<4 {
            app.swipeUp(velocity: .slow)
            if card.exists && card.isHittable { return card }
        }
        for _ in 0..<8 {
            app.swipeDown(velocity: .slow)
            if card.exists && card.isHittable { return card }
        }
        XCTFail("Game card \(gameID) not found in the schedule", file: file, line: line)
        return card
    }

    /// Games tab → tap the game card → BetSheet.
    private func openBetSheet(forGame gameID: Int, via screen: GroupDetailScreen) -> BetSheetScreen {
        scrollTo(screen.gamesTab).tap()
        locateGameCard(gameID, via: screen).tap()
        let sheet = BetSheetScreen(app: app)
        waitFor(sheet.header)
        return sheet
    }

    /// Mirror of `scrollTo` that swipes DOWN (content above the viewport — the games
    /// tab auto-anchors past earlier days).
    @discardableResult
    private func scrollUpTo(_ element: XCUIElement, maxSwipes: Int = 6,
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return element }
            app.swipeDown(velocity: .slow)
        }
        if !element.exists {
            XCTFail("Element not found after scrolling up: \(element)", file: file, line: line)
        }
        return element
    }

    private func waitForLabel(_ element: XCUIElement, contains fragment: String,
                              timeout: TimeInterval = 12,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            let current = element.exists ? element.label : "(element missing)"
            XCTFail("Label never contained '\(fragment)'. Last: \(current)", file: file, line: line)
        }
    }

    private func assertLabel(_ element: XCUIElement, contains fragment: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.label.contains(fragment),
                      "Expected label to contain '\(fragment)', got '\(element.label)'",
                      file: file, line: line)
    }

    private func assertLabel(_ element: XCUIElement, notContains fragment: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(element.label.contains(fragment),
                       "Expected label NOT to contain '\(fragment)', got '\(element.label)'",
                       file: file, line: line)
    }

    // MARK: - Group tab anatomy

    /// Hero stats (rank/games-played/ACTIVE), welcome card, TOP 3, invite link,
    /// nickname, roster, visibility, house rules (sneak peek "Allowed"), meme-board
    /// link and leave button — the full GROUP-tab inventory for a running group.
    func testGroupTabRendersHeroStatsAndSidebarCards() {
        launchApp()
        openSundayLegends()

        // Hero: kicker, counts, state, rank/progress tiles, author cover CTA.
        waitFor(staticText(containing: "EURO CUP 2026"))
        XCTAssertTrue(app.staticTexts["3 MEMBERS"].exists)
        waitFor(app.staticTexts["1 OF 3 GAMES"], timeout: 15)
        XCTAssertTrue(staticText(containing: "ACTIVE").exists)
        XCTAssertTrue(app.staticTexts["YOUR RANK"].exists)
        XCTAssertTrue(app.staticTexts["02"].exists)   // alex: 7 > 5 > 3 → place 2, zero-padded
        XCTAssertTrue(app.staticTexts["OF 03"].exists)
        XCTAssertTrue(app.staticTexts["GAMES PLAYED"].exists)
        XCTAssertTrue(app.staticTexts["33"].exists)   // 1 of 3 finished → 33 %
        // PhotosPicker surfaces as a button, not a static text — match any element type.
        let coverCTA = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "ADD COVER")).firstMatch
        XCTAssertTrue(coverCTA.waitForExistence(timeout: 5), "author-only upload boundary")

        // Welcome / description card.
        scrollTo(app.staticTexts["Bring your A-game."])
        XCTAssertTrue(app.staticTexts["The original crew."].exists)

        // TOP 3 + invite link (running tournament only).
        scrollTo(staticText(containing: "TOP 3"))
        scrollTo(staticText(containing: "SUNLEG"))
        XCTAssertTrue(app.buttons["COPY →"].exists)

        // Nickname + roster.
        scrollTo(staticText(containing: "YOUR NICKNAME"))
        scrollTo(staticText(containing: "ONE CHAMPION."))

        // Visibility (private by default) + house rules with sneak peek Allowed.
        scrollTo(staticText(containing: "VISIBILITY"))
        XCTAssertTrue(staticText(containing: "PRIVATE").exists)
        scrollTo(staticText(containing: "HOUSE RULES"))
        XCTAssertTrue(app.staticTexts["Winning team"].exists)
        XCTAssertTrue(app.staticTexts["1 pts"].exists)
        XCTAssertTrue(app.staticTexts["Exact score"].exists)
        XCTAssertTrue(app.staticTexts["3 pts"].exists)
        XCTAssertTrue(app.staticTexts["Sneak peek"].exists)
        XCTAssertTrue(app.staticTexts["Allowed"].exists)
        XCTAssertTrue(app.buttons["EDIT →"].exists)   // alex is the author

        scrollTo(app.buttons["OPEN MEME BOARD →"])
        scrollTo(app.buttons["LEAVE GROUP"])
    }

    // MARK: - Leaderboard

    /// Score-descending rows with zero-padded places, nickname preferred over the
    /// real name, and the YOU badge on the signed-in member's row.
    func testLeaderboardRendersDenseRankingZeroPaddedWithYouBadge() {
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.leaderboardTab).tap()

        let row0 = waitFor(screen.leaderboardRow(0))
        assertLabel(row0, contains: "01")
        assertLabel(row0, contains: "The Oracle")   // nickname, NOT "Robin Rival"
        assertLabel(row0, notContains: "Robin Rival")
        assertLabel(row0, contains: "7")

        let row1 = waitFor(screen.leaderboardRow(1))
        assertLabel(row1, contains: "02")
        assertLabel(row1, contains: "Alex Tester")
        assertLabel(row1, contains: "YOU")
        assertLabel(row1, contains: "5")

        let row2 = waitFor(screen.leaderboardRow(2))
        assertLabel(row2, contains: "03")
        assertLabel(row2, contains: "Casey Friend")
        assertLabel(row2, contains: "3")
        assertLabel(row0, notContains: "YOU")
    }

    /// DENSE tie ranking pin: 7, 7, 3 → places 01, 01, 02 (NOT competition 1,1,3).
    func testLeaderboardTiedScoresSharePlaceDense() {
        withScenario { $0.groupDetailSetMemberScore(userID: DefaultScenario.currentUserID, score: 7) }
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.leaderboardTab).tap()

        // Both 7-point members share place 01 (intra-tie order is unspecified).
        let row0 = waitFor(screen.leaderboardRow(0))
        let row1 = waitFor(screen.leaderboardRow(1))
        assertLabel(row0, contains: "01")
        assertLabel(row1, contains: "01")
        let tiedLabels = row0.label + " | " + row1.label
        XCTAssertTrue(tiedLabels.contains("Alex Tester"), "tied rows: \(tiedLabels)")
        XCTAssertTrue(tiedLabels.contains("The Oracle"), "tied rows: \(tiedLabels)")

        let row2 = waitFor(screen.leaderboardRow(2))
        assertLabel(row2, contains: "02")           // dense: next distinct score = place + 1
        assertLabel(row2, contains: "Casey Friend")
        assertLabel(row2, notContains: "03")
    }

    /// TOP 3 podium card: exactly the three highest scorers, score-descending.
    func testTopThreeShowsOnlyTopThreeMembers() {
        withScenario { $0.groupDetailAddMember(userID: DefaultScenario.adminUserID, score: 1) }
        launchApp()
        let screen = openSundayLegends()

        scrollTo(staticText(containing: "TOP 3"))
        waitFor(screen.topThreeMember(0))
        XCTAssertEqual(screen.topThreeMember(0).label, "The Oracle")
        XCTAssertEqual(screen.topThreeMember(1).label, "Alex Tester")
        XCTAssertEqual(screen.topThreeMember(2).label, "Casey Friend")
        XCTAssertFalse(screen.topThreeMember(3).exists)
        XCTAssertFalse(app.buttons["Betty Admin"].exists) // 4th member never on the podium
    }

    /// Tapping a leaderboard row opens the member's bet history: "<N> BETS · <Σ> PTS",
    /// rows kickoff-ascending, points chip once processed.
    func testLeaderboardMemberRowOpensBetHistorySheet() {
        withScenario {
            $0.groupDetailAddBet(userID: DefaultScenario.rivalUserID,
                                 gameID: DefaultScenario.finishedGameID,
                                 home: 2, away: 1, points: 3, processed: true)
            $0.groupDetailAddBet(userID: DefaultScenario.rivalUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 1, away: 0)
        }
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.leaderboardTab).tap()
        waitFor(screen.leaderboardRow(0)).tap()

        let history = UserHistorySheetScreen(app: app)
        waitFor(history.root)
        waitFor(app.staticTexts["THE ORACLE"])
        XCTAssertTrue(app.staticTexts["2 BETS"].exists)
        XCTAssertTrue(app.staticTexts["3 PTS"].exists)

        // Ascending by kickoff: finished (-2 d) before upcoming (+2 h).
        let row0 = waitFor(history.row(0))
        assertLabel(row0, contains: "+3P")
        assertLabel(row0, contains: "2")
        assertLabel(row0, contains: "1")
        let row1 = waitFor(history.row(1))
        assertLabel(row1, contains: "1")            // sneak peek allowed → score visible
        assertLabel(row1, contains: "0")
        assertLabel(row1, notContains: "+")          // unprocessed → points pending
        assertLabel(row1, notContains: "0P")
    }

    // MARK: - Games tab

    /// Row states: upcoming (no LIVE/FINISHED, tappable bet CTA), live (LIVE badge +
    /// your placed-bet chip), finished (FINISHED + final score + awarded points,
    /// "Group"-named pools collapse headers to the day title only).
    func testGamesTabGameRowStatesUpcomingLiveFinished() {
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.gamesTab).tap()

        // Live: LIVE badge replaces the date label; own 2-0 bet shows as a chip.
        let live = locateGameCard(DefaultScenario.liveGameID, via: screen)
        assertLabel(live, contains: "LIVE")
        assertLabel(live, contains: "Your bet 2 to 0")
        assertLabel(live, contains: "SPAIN")
        assertLabel(live, contains: "FRANCE")

        // Upcoming: plain date label, no LIVE, no FINISHED — the bet CTA.
        let upcoming = locateGameCard(DefaultScenario.upcomingGameID, via: screen)
        assertLabel(upcoming, notContains: "LIVE")
        assertLabel(upcoming, notContains: "FINISHED")
        assertLabel(upcoming, contains: "SWEDEN")
        assertLabel(upcoming, contains: "ENGLAND")

        // Finished: FINISHED label, final 2-1, awarded points 3P from the evaluated bet.
        let finished = locateGameCard(DefaultScenario.finishedGameID, via: screen)
        assertLabel(finished, contains: "FINISHED")
        assertLabel(finished, contains: "3P")
        assertLabel(finished, contains: "2")
        assertLabel(finished, contains: "1")

        // Pool names contain "Group" → header is the day title ONLY.
        XCTAssertTrue(app.staticTexts["2 DAYS AGO"].exists)
        XCTAssertFalse(staticText(containing: "GROUP B -").exists)
    }

    /// Day grouping with non-"Group" pool names: "<POOL> - <DAY>" headers and the
    /// orange next-upcoming marker on the day of the first not-yet-started game.
    func testGamesTabGroupsByDayWithPoolNameHeaders() {
        withScenario { $0.groupDetailRenamePools(["Quarter-final", "Semi-final"]) }
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.gamesTab).tap()

        // The upcoming game (+2 h) anchors the ● marker; compute today/tomorrow at
        // runtime so the test is stable across day boundaries.
        let upcomingDay = Calendar.current.isDateInToday(Date().addingTimeInterval(2 * 3600))
            ? "TODAY" : "TOMORROW"
        waitFor(app.staticTexts["● QUARTER-FINAL - \(upcomingDay)"], timeout: 15)

        // Finished game day (pool "Semi-final", always exactly 2 calendar days back).
        scrollUpTo(app.staticTexts["SEMI-FINAL - 2 DAYS AGO"], maxSwipes: 8)
    }

    // MARK: - Bet sheet: placing & editing

    /// Save needs BOTH fields non-empty; steppers clamp at 0; CTA reads PLACE BET
    /// when no bet exists yet.
    func testBetSheetValidationRequiresBothScoresBeforeSave() {
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.submitButton)
        assertLabel(sheet.submitButton, contains: "PLACE BET")
        XCTAssertFalse(sheet.submitButton.isEnabled)         // both fields empty

        sheet.homePlus.tap()
        XCTAssertEqual(sheet.homeField.value as? String, "1")
        XCTAssertFalse(sheet.submitButton.isEnabled)         // away still empty

        sheet.awayMinus.tap()                                // minus on empty clamps to 0
        XCTAssertEqual(sheet.awayField.value as? String, "0")
        XCTAssertTrue(sheet.submitButton.isEnabled)          // both non-empty → can save

        sheet.awayMinus.tap()                                // min 0 — never negative
        XCTAssertEqual(sheet.awayField.value as? String, "0")
    }

    /// New bet → POST /bet with is_universal (checkbox default ON) → 200, sheet
    /// dismisses, schedule card shows the placed-bet chip, and the universal fan-out
    /// lands in every group of the tournament.
    func testPlaceBetPostsUniversalAndReflectsInSchedule() {
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        sheet.homePlus.tap()
        sheet.homePlus.tap()
        sheet.awayPlus.tap()
        XCTAssertEqual(sheet.universalToggle.value as? String, "1") // default ON (web pin)
        waitFor(sheet.submitButton).tap()
        waitForDisappearance(sheet.header)

        let posts = backend.requests(method: "POST", pathPrefix: "/api/v1/bet")
        XCTAssertEqual(posts.count, 1)
        let body = posts.first?.bodyJSON
        XCTAssertEqual(body?["game_id"] as? Int, DefaultScenario.upcomingGameID)
        XCTAssertEqual(body?["group_id"] as? Int, DefaultScenario.groupSundayLegendsID)
        XCTAssertEqual(body?["home_team_score"] as? Int, 2)
        XCTAssertEqual(body?["away_team_score"] as? Int, 1)
        XCTAssertEqual(body?["is_universal"] as? Bool, true)

        // UI reflects the bet on the game row.
        waitForLabel(screen.gameCard(DefaultScenario.upcomingGameID), contains: "Your bet 2 to 1")

        // Universal upsert reached the OTHER tournament group too (server-side state).
        let fannedOut = withScenario { scenario in
            scenario.bets.contains {
                $0.userID == DefaultScenario.currentUserID
                    && $0.gameID == DefaultScenario.upcomingGameID
                    && $0.groupID == DefaultScenario.groupOfficeRoyaleID
                    && $0.homeTeamScore == 2 && $0.awayTeamScore == 1
            }
        }
        XCTAssertTrue(fannedOut)
    }

    /// Existing bet + checkbox OFF → PUT /bet/:id (single-group edit), never POST.
    func testEditBetUncheckedUniversalSendsSingleGroupPut() {
        withScenario {
            $0.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 1, away: 1)
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        // Prefilled from the existing bet, CTA flips to UPDATE BET.
        waitFor(sheet.submitButton)
        XCTAssertEqual(sheet.homeField.value as? String, "1")
        XCTAssertEqual(sheet.awayField.value as? String, "1")
        assertLabel(sheet.submitButton, contains: "UPDATE BET")

        sheet.tapUniversalToggle()
        XCTAssertEqual(sheet.universalToggle.value as? String, "0")
        sheet.homePlus.tap()                                  // 1 → 2
        sheet.submitButton.tap()
        waitForDisappearance(sheet.header)

        let puts = backend.requests(method: "PUT", pathPrefix: "/api/v1/bet/")
        XCTAssertEqual(puts.count, 1)
        XCTAssertEqual(puts.first?.bodyJSON?["home_team_score"] as? Int, 2)
        XCTAssertEqual(puts.first?.bodyJSON?["away_team_score"] as? Int, 1)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/api/v1/bet").isEmpty)

        waitForLabel(screen.gameCard(DefaultScenario.upcomingGameID), contains: "Your bet 2 to 1")
    }

    /// CRITICAL regression pin: editing with the all-groups checkbox ON must RE-POST
    /// with is_universal (PUT would only touch one bet).
    func testEditBetCheckedUniversalRepostsToAllGroups() {
        withScenario {
            $0.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 1, away: 1)
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.submitButton)
        assertLabel(sheet.submitButton, contains: "UPDATE BET")
        XCTAssertEqual(sheet.universalToggle.value as? String, "1") // leave checked
        sheet.homePlus.tap()                                  // 1 → 2
        sheet.submitButton.tap()
        waitForDisappearance(sheet.header)

        let posts = backend.requests(method: "POST", pathPrefix: "/api/v1/bet")
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.bodyJSON?["is_universal"] as? Bool, true)
        XCTAssertEqual(posts.first?.bodyJSON?["home_team_score"] as? Int, 2)
        XCTAssertTrue(backend.requests(method: "PUT", pathPrefix: "/api/v1/bet/").isEmpty)

        // Upserted across both running-tournament groups.
        let officeBet = withScenario { scenario in
            scenario.bets.first {
                $0.userID == DefaultScenario.currentUserID
                    && $0.gameID == DefaultScenario.upcomingGameID
                    && $0.groupID == DefaultScenario.groupOfficeRoyaleID
            }
        }
        XCTAssertEqual(officeBet?.homeTeamScore, 2)
        XCTAssertEqual(officeBet?.awayTeamScore, 1)
    }

    /// POST /bet → 423 (game started server-side) → "betting closed" error panel,
    /// sheet stays open, submit re-enables.
    func testBetOnStartedGameShowsBettingClosed423Error() {
        launchApp()
        // Last registration wins: force the bet endpoint to answer 423.
        backend.http.route("POST", "/api/v1/bet") { _, _ in .empty(423) }

        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)
        sheet.homePlus.tap()
        sheet.awayPlus.tap()
        waitFor(sheet.submitButton).tap()

        waitFor(staticText(containing: "Betting is closed"))
        XCTAssertTrue(staticText(containing: "already started").exists)
        XCTAssertTrue(sheet.header.exists)                    // sheet did NOT dismiss
        XCTAssertTrue(sheet.submitButton.isEnabled)           // button re-enabled for retry
    }

    /// After kickoff the "Your bet" tab is REMOVED (not disabled), the sheet forces
    /// Placed bets, and the footer (toggle + submit) is gone.
    func testLiveGameBetSheetRemovesYourBetTabAndFooter() {
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.liveGameID, via: screen)

        waitFor(sheet.placedTab)
        XCTAssertFalse(sheet.yourBetTab.exists)
        XCTAssertFalse(sheet.submitButton.exists)
        XCTAssertFalse(sheet.universalToggle.exists)

        // Kickoff passed → scores visible regardless of sneak peek; bet unprocessed
        // → no points chip yet.
        let row = waitFor(sheet.placedRow(0))
        assertLabel(row, contains: "Alex Tester")
        assertLabel(row, contains: "2 – 0")
        assertLabel(row, notContains: "0P")
        assertLabel(row, notContains: "+")
    }

    // MARK: - Sneak peek / HiddenScore

    /// Pre-kickoff, sneak peek disallowed → opponents' placed bets render the
    /// HiddenScore placeholder instead of the score.
    func testBetSheetHidesOpponentScoresWithoutSneakPeek() {
        withScenario {
            $0.groupDetailSetSneakPeek(false)
            $0.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 2, away: 2)
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.placedTab).tap()
        let row = waitFor(sheet.placedRow(0))
        assertLabel(row, contains: "Casey Friend")
        assertLabel(row, notContains: "2 – 2")
        assertLabel(row, notContains: "2")                    // no score digits leak at all
    }

    /// `allow_sneak_peek` reveals opponents' pre-kickoff bets; the footer is hidden
    /// while the Placed bets tab is selected and returns on Your bet.
    func testBetSheetShowsOpponentScoresWithSneakPeek() {
        withScenario {
            $0.groupDetailAddBet(userID: DefaultScenario.friendUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 2, away: 2)
        }
        launchApp()
        let screen = openSundayLegends()
        let sheet = openBetSheet(forGame: DefaultScenario.upcomingGameID, via: screen)

        waitFor(sheet.placedTab).tap()
        let row = waitFor(sheet.placedRow(0))
        assertLabel(row, contains: "Casey Friend")
        assertLabel(row, contains: "2 – 2")                   // peek ON → visible pre-kickoff
        XCTAssertFalse(sheet.submitButton.exists)             // footer hidden on Placed tab

        sheet.yourBetTab.tap()
        waitFor(sheet.submitButton)
    }

    /// Member history without sneak peek: processed bets show score + points chip,
    /// an opponent's un-started bet stays hidden with a pending dot.
    func testMemberHistoryHidesUpcomingOpponentScoreWithoutSneakPeek() {
        withScenario {
            $0.groupDetailSetSneakPeek(false)
            $0.groupDetailAddBet(userID: DefaultScenario.rivalUserID,
                                 gameID: DefaultScenario.finishedGameID,
                                 home: 2, away: 1, points: 3, processed: true)
            $0.groupDetailAddBet(userID: DefaultScenario.rivalUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 1, away: 0)
        }
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.leaderboardTab).tap()
        waitFor(screen.leaderboardRow(0)).tap()

        let history = UserHistorySheetScreen(app: app)
        waitFor(history.root)
        waitFor(app.staticTexts["THE ORACLE"])

        let row0 = waitFor(history.row(0))                    // processed → fully visible
        assertLabel(row0, contains: "+3P")
        let row1 = waitFor(history.row(1))                    // upcoming opponent bet → hidden
        assertLabel(row1, notContains: "1")
        assertLabel(row1, notContains: "0")
        assertLabel(row1, notContains: "P")
    }

    /// You always see YOUR OWN pre-kickoff score, but points stay pending until
    /// processed (isMine does not unlock points — web pin).
    func testOwnHistoryShowsOwnUpcomingScoreWithPendingPoints() {
        withScenario {
            $0.groupDetailSetSneakPeek(false)
            $0.groupDetailAddBet(userID: DefaultScenario.currentUserID,
                                 gameID: DefaultScenario.upcomingGameID,
                                 home: 1, away: 0)
        }
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.leaderboardTab).tap()
        waitFor(screen.leaderboardRow(1)).tap()               // place 02 = Alex (YOU)

        let history = UserHistorySheetScreen(app: app)
        waitFor(history.root)
        waitFor(app.staticTexts["ALEX TESTER"])
        XCTAssertTrue(app.staticTexts["3 BETS"].exists)       // finished + live + upcoming
        XCTAssertTrue(app.staticTexts["3 PTS"].exists)

        // Rows ascend by kickoff: finished (-2 d), live (-45 min), upcoming (+2 h).
        let finishedRow = waitFor(history.row(0))
        assertLabel(finishedRow, contains: "+3P")
        let upcomingRow = waitFor(history.row(2))
        assertLabel(upcomingRow, contains: "1")               // own score visible pre-kickoff
        assertLabel(upcomingRow, contains: "0")
        assertLabel(upcomingRow, notContains: "+")            // … but points still pending
        assertLabel(upcomingRow, notContains: "0P")
    }

    // MARK: - Ended tournament

    /// Ended tournament: Games tab disappears, hero shows CHAMPION/“YOU WON” + YOUR
    /// FINISH, and the GROUP tab renders the final podium whose people open their
    /// bet history.
    func testEndedTournamentShowsFinalPodiumAndHidesGamesTab() {
        // Push Legacy League beyond the 28-day "recently ended" window — only then does
        // Wrapped Winners move from Running (JUST ENDED badge) to the Ended tab.
        withScenario { $0.homeEndTournamentBeyondRecentWindow(DefaultScenario.endedTournamentID) }
        launchApp()
        let screen = openGroup(named: "Wrapped Winners", ended: true)

        waitFor(screen.groupTab)
        XCTAssertTrue(screen.leaderboardTab.exists)
        XCTAssertFalse(screen.gamesTab.exists)                // hidden once ended
        XCTAssertTrue(staticText(containing: "FINAL").exists)

        // Hero champion tiles: alex (9) beat casey (6).
        waitFor(app.staticTexts["YOU WON"])
        XCTAssertTrue(app.staticTexts["Alex Tester"].exists)
        XCTAssertTrue(app.staticTexts["9 PTS"].exists)
        XCTAssertTrue(app.staticTexts["YOUR FINISH"].exists)
        XCTAssertTrue(app.staticTexts["01"].exists)

        // Final podium with per-place slots.
        scrollTo(staticText(containing: "FINAL PODIUM"))
        XCTAssertTrue(staticText(containing: "YOU TOOK IT.").exists)
        let first = waitFor(screen.podiumMember(place: 1))
        assertLabel(first, contains: "Alex Tester")
        assertLabel(first, contains: "9 PTS")
        let second = waitFor(screen.podiumMember(place: 2))
        assertLabel(second, contains: "Casey Friend")
        assertLabel(second, contains: "6 PTS")
        XCTAssertTrue(app.buttons["SEE FULL LEADERBOARD →"].exists)

        // Podium person → bet history (no games in the ended tournament → empty state).
        second.tap()
        let history = UserHistorySheetScreen(app: app)
        waitFor(history.root)
        waitFor(app.staticTexts["CASEY FRIEND"])
        XCTAssertTrue(app.staticTexts["0 BETS"].exists)
        waitFor(history.emptyState)
    }

    // MARK: - Need-action strip

    /// GROUP tab urgent strip: the un-bet game kicking off within 24 h renders under
    /// the warning header and opens the BetSheet on tap.
    func testNeedActionStripShowsUrgentGameAndOpensBetSheet() {
        launchApp()
        let screen = openSundayLegends()

        scrollTo(staticText(containing: "MAKE SURE TO BET"))
        let card = scrollTo(screen.gameCard(DefaultScenario.upcomingGameID))
        assertLabel(card, contains: "SWEDEN")
        card.tap()

        let sheet = BetSheetScreen(app: app)
        waitFor(sheet.header)
        XCTAssertTrue(sheet.yourBetTab.exists)                // upcoming → input available
        sheet.closeButton.tap()
        waitForDisappearance(sheet.header)
    }

    // MARK: - Live updates

    /// `evaluate_game` WS push forces a tournament reload: the live card flips to
    /// FINISHED with the final score without any user interaction.
    func testEvaluateGameWebSocketPushRefreshesSchedule() {
        launchApp()
        let screen = openSundayLegends()
        scrollTo(screen.gamesTab).tap()

        let card = locateGameCard(DefaultScenario.liveGameID, via: screen)
        assertLabel(card, contains: "LIVE")

        waitForWebSocketClient()
        withScenario {
            $0.updateGame(DefaultScenario.liveGameID) { game in
                game.status = 1
                game.homeTeamScore = 3
                game.awayTeamScore = 2
            }
        }
        pushWS(type: "evaluate_game", message: [
            "game_id": DefaultScenario.liveGameID,
            "home_team_score": 3,
            "away_team_score": 2,
        ])

        waitForLabel(screen.gameCard(DefaultScenario.liveGameID), contains: "FINISHED", timeout: 15)
        assertLabel(screen.gameCard(DefaultScenario.liveGameID), contains: "3")
        assertLabel(screen.gameCard(DefaultScenario.liveGameID), notContains: "LIVE")
    }
}
