import XCTest

// Auth-area gap coverage on top of AuthE2ETests:
// - the signed-in boot bootstrap failure surface (RootView's BootFailedView,
//   "Could not load your data") and its retry recovery,
// - pending deep-link stash & replay across an interactive sign-in (the web
//   returnUrl analogue) plus the cold-start (app-not-running) deep-link launch,
//   both driven via the betty:// scheme (no associated-domain dependency).

// MARK: - Boot bootstrap failure (teams/tournaments/groups fan-out)

final class AuthBootFailureE2ETests: BettyUITestCase {
    func testBootstrapFailureShowsCouldNotLoadAndRetryRecovers() {
        // Fail one leg of the parallel boot fan-out — `try await (teams, tournaments,
        // groups)` rethrows and RootView must swap in BootFailedView instead of Home.
        backend.api("GET", "/tournaments") { _, _, _, _ in .empty(500) }
        launchApp()

        waitFor(element(app, id: "root.bootFailed"), timeout: 25)
        waitFor(staticText(containing: "Could not load your data"))
        XCTAssertTrue(staticText(containing: "Check your connection and try again").exists)
        XCTAssertFalse(element(app, id: "root.main").exists,
                       "a failed bootstrap must never show the (empty) dashboard")
        XCTAssertFalse(element(app, id: "root.authLanding").exists,
                       "a boot failure is not a sign-out")
        let retryButton = waitFor(app.buttons["TRY AGAIN"]) // BettyButtonStyle uppercases labels

        // Server back up → retry re-runs onSignedIn() and recovers without a relaunch.
        backend.authRestoreTournamentsRoute()
        let attemptsBefore = backend.requests(method: "GET", pathPrefix: "/api/v1/tournaments").count
        retryButton.tap()

        waitFor(element(app, id: "root.main"), timeout: 25)
        waitFor(HomeScreen(app: app).navigationBar, timeout: 15)
        XCTAssertFalse(element(app, id: "root.bootFailed").exists)
        XCTAssertGreaterThan(
            backend.requests(method: "GET", pathPrefix: "/api/v1/tournaments").count,
            attemptsBefore,
            "retry must re-run the boot fan-out, not just dismiss the screen")
    }
}

// MARK: - Deep-link stash & replay (betty://join/<code>)

final class AuthDeepLinkE2ETests: BettyUITestCase {
    override var seedsAuthentication: Bool { false }

    private let joinURL = URL(string: "betty://join/OPENAR")!
    private var join: JoinInvitePage { JoinInvitePage(app: app) }
    private var landing: AuthLandingScreen { AuthLandingScreen(app: app) }

    /// betty://join/<code> while signed out is stashed (web returnUrl analogue) and
    /// replayed exactly once after the interactive sign-in completes.
    func testJoinLinkWhileSignedOutIsStashedAndReplayedAfterSignIn() {
        launchApp() // signed out → landing
        waitFor(landing.root, timeout: 20)

        app.open(joinURL)

        // Stashed, not acted on: still the landing, no sheet, and crucially no
        // GET /group/<code> peek (the sheet's first request) may have fired.
        waitFor(landing.root)
        XCTAssertFalse(join.groupNameTitle.waitForExistence(timeout: 3),
                       "the join sheet must not present over the signed-out landing")
        XCTAssertTrue(backend.requests(method: "GET", pathPrefix: "/api/v1/group/OPENAR").isEmpty)

        scrollTo(landing.showEmailFormButton)
        landing.showEmailFormButton.tap()
        waitFor(landing.emailField)
        landing.fillEmailForm(email: DefaultScenario.currentUserEmail,
                              password: DefaultScenario.currentUserPassword)
        scrollTo(landing.signInSubmitButton)
        landing.signInSubmitButton.tap()

        waitFor(element(app, id: "root.main"), timeout: 25)
        dismissSavePasswordPromptIfPresent()

        // Post-bootstrap replay: the join sheet for "Open Arena" (public group, not a
        // member) with the peek actually fetched.
        waitFor(join.groupNameTitle, timeout: 20)
        XCTAssertEqual(join.groupNameTitle.label, "OPEN ARENA")
        XCTAssertTrue(join.acceptButton.exists)
        XCTAssertFalse(backend.requests(method: "GET", pathPrefix: "/api/v1/group/OPENAR").isEmpty)

        // Replayed ONCE: declining must not resurrect the stashed link.
        join.declineButton.tap()
        waitForDisappearance(join.groupNameTitle)
        XCTAssertFalse(join.groupNameTitle.waitForExistence(timeout: 3),
                       "a replayed deep link must be consumed, not re-presented")
        XCTAssertTrue(element(app, id: "root.main").exists)
    }

    /// Cold start: the app is NOT running when the link arrives — the OS launches it
    /// with the URL, the seeded session restores, and the boot replays the link.
    func testColdStartJoinLinkOpensJoinSheetAfterSeededBoot() {
        // Seed the session by hand (launchApp would `launch()` first — the point here
        // is that open(_:) itself performs the cold launch carrying the URL).
        app.launchEnvironment["BETTY_SEED_REFRESH_TOKEN"] =
            backend.refreshToken(for: DefaultScenario.currentUserID)
        app.launchEnvironment["BETTY_SEED_UID"] = DefaultScenario.currentUserID

        app.open(joinURL)

        waitFor(element(app, id: "root.main"), timeout: 30)
        waitFor(join.groupNameTitle, timeout: 20)
        XCTAssertEqual(join.groupNameTitle.label, "OPEN ARENA")
        XCTAssertFalse(backend.requests(method: "GET", pathPrefix: "/api/v1/group/OPENAR").isEmpty)

        // The session came from the seeded refresh token (no interactive sign-in).
        XCTAssertFalse(backend.requests(method: "POST", pathPrefix: "/v1/token").isEmpty)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:").isEmpty)

        // Accepting completes the deep-link journey end to end.
        join.acceptButton.tap()
        waitForDisappearance(join.groupNameTitle, timeout: 15)
        let joins = backend.requests(method: "POST", pathPrefix: "/api/v1/join/OPENAR")
        XCTAssertEqual(joins.count, 1)
    }
}
