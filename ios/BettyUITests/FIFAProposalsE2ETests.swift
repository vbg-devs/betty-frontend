import XCTest

/// Web `/admin/fifa` "Review results" on iOS — the admin FIFA proposals inbox reached
/// from the profile Admin area. Exercises the wire→UI path (team names + score from the
/// enriched proposal) and the confirm flow (applies through the backend, drops the row).
final class FIFAProposalsE2ETests: BettyUITestCase {
    override var seededUserID: String { DefaultScenario.adminUserID }

    override func makeScenario() -> MockScenario {
        var scenario = DefaultScenario.build()
        scenario.fifaProposals = [
            MockFIFAProposal(
                id: 1, gameID: DefaultScenario.liveGameID, matchID: "400021440",
                homeTeamScore: 2, awayTeamScore: 1,
                gameHomeTeam: "Spain", gameAwayTeam: "France",
                gameStartDate: Date().addingTimeInterval(-3600)
            ),
        ]
        return scenario
    }

    private func openFIFAResults() {
        launchApp()
        waitFor(TabBarScreen(app: app).profile, timeout: 20).tap()
        scrollTo(app.buttons["profile.links.adminFIFA"]).tap()
    }

    func testAdminSeesProposalWithTeamsAndScore() {
        openFIFAResults()
        // The row renders the betty matchup from the enriched wire fields, not an id.
        waitFor(app.buttons["admin.fifa.confirm.1"])
        XCTAssertTrue(staticText(containing: "Spain").exists)
        XCTAssertTrue(staticText(containing: "France").exists)
    }

    func testConfirmAppliesAndRemovesRow() {
        openFIFAResults()
        waitFor(app.buttons["admin.fifa.confirm.1"]).tap()
        // The confirm flows through the shared toast confirm prompt.
        waitFor(app.buttons["live.toast.confirm"]).tap()
        // Applied → drops off the Pending tab, and the backend got the confirm POST.
        waitForDisappearance(app.buttons["admin.fifa.confirm.1"])
        XCTAssertFalse(
            backend.requests(method: "POST", pathPrefix: "/api/v1/admin/fifa/proposals/1/confirm").isEmpty,
            "confirm should POST to the backend"
        )
    }
}
