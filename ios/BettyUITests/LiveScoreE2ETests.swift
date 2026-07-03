import XCTest

/// Tentative (live) game scores — cold-load LIVE badge from `live_status=1` and an
/// in-place score update on a pushed `live_score_update` frame (api-contract §4, §6;
/// display precedence spec §7). Uses its own scenario so the shared DefaultScenario
/// (and the evaluate_game live-score test) are unaffected.
final class LiveScoreE2ETests: LiveE2EBase {

    /// Seed the running tournament's live game (Spain vs France) as in-progress 1-0.
    override func makeScenario() -> MockScenario {
        var scenario = DefaultScenario.build()
        scenario.updateGame(DefaultScenario.liveGameID) { game in
            game.liveHomeTeamScore = 1
            game.liveAwayTeamScore = 0
            game.liveStatus = 1
        }
        return scenario
    }

    /// Cold load renders the LIVE badge + live score; a pushed `live_score_update`
    /// updates the score in place with NO pull-to-refresh or tab switch.
    func testLiveScoreShowsBadgeOnColdLoadAndUpdatesInPlace() {
        launchApp()
        openGroup("Sunday Legends")
        let detail = GroupDetailScreen(app: app)
        waitFor(detail.gamesTab, timeout: 15).tap()

        let board = LiveScoreboardScreen(app: app)
        scrollTo(board.team("Spain"))
        waitFor(board.team("France"), timeout: 5)

        // Cold load: live_status=1 renders the LIVE badge (not FT).
        waitFor(app.staticTexts["LIVE"].firstMatch, timeout: 10)
        XCTAssertFalse(app.staticTexts["FT"].exists, "A live game must not show the FT badge")

        // Pushed live_score_update updates the visible score in place (5 is distinctive
        // among the scenario's 0/1/2 scores), driven ONLY by the WS event.
        waitForWebSocketClient()
        pushWS(type: "live_score_update",
               message: LiveWire.liveScoreUpdate(gameID: DefaultScenario.liveGameID, home: 5, away: 0, liveStatus: 1))
        waitFor(board.scoreDigit(5), timeout: 15)
        // Still LIVE after the update.
        XCTAssertTrue(app.staticTexts["LIVE"].firstMatch.exists)
    }

    /// Screenshot generator (not an assertion test) — run with
    /// TEST_RUNNER_BETTY_SCREENSHOTS=1 and export the .keepAlways attachments.
    func testCaptureLiveScoreScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["BETTY_SCREENSHOTS"] == "1",
            "Screenshot generator — run with TEST_RUNNER_BETTY_SCREENSHOTS=1"
        )

        launchApp()
        openGroup("Sunday Legends")
        let detail = GroupDetailScreen(app: app)
        waitFor(detail.gamesTab, timeout: 15).tap()

        let board = LiveScoreboardScreen(app: app)
        scrollTo(board.team("Spain"))
        waitFor(app.staticTexts["LIVE"].firstMatch, timeout: 10)
        snap("01_live_badge")

        // Push a full-time frame → the card flips to the neutral FT badge.
        waitForWebSocketClient()
        pushWS(type: "live_score_update",
               message: LiveWire.liveScoreUpdate(gameID: DefaultScenario.liveGameID, home: 2, away: 1, liveStatus: 2))
        waitFor(app.staticTexts["FT"].firstMatch, timeout: 15)
        snap("02_full_time_badge")
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
