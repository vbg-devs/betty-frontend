import XCTest

/// Harness smoke: the mock backend boots, the app honors the launch-environment
/// overrides, seeded auth works, and the WebSocket push path is real end-to-end.
final class SmokeTests: BettyUITestCase {
    /// (a) Signed-out launch lands on the auth landing screen.
    func testSignedOutLaunchShowsAuthLanding() {
        launchApp(seedAuth: false)
        let landing = AuthLandingScreen(app: app)
        waitFor(landing.root, timeout: 15)
        waitFor(landing.appleButton)
        XCTAssertTrue(landing.googleButton.exists)
    }

    /// (b) Seeded-auth launch boots straight to Home and renders the DefaultScenario
    /// group names served by the mock API.
    func testSeededLaunchShowsDefaultScenarioGroups() {
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(TabBarScreen(app: app).home, timeout: 30)
        waitFor(home.navigationBar, timeout: 15)
        scrollTo(home.groupCard(named: "Sunday Legends"))
        scrollTo(home.groupCard(named: "Office Royale"))
    }

    /// (c) A WebSocket push from the test reaches the app and renders in the Activity
    /// feed (global event ticker).
    func testWebSocketPushAppearsInActivityFeed() {
        launchApp()
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.activity, timeout: 20)
        tabs.activity.tap()

        let activity = ActivityScreen(app: app)
        waitFor(activity.navigationBar, timeout: 10)
        waitForWebSocketClient()
        pushWS(type: "group_joined", message: [
            "group": ["id": DefaultScenario.groupSundayLegendsID, "name": "Sunday Legends"],
            "who": "Casey Friend",
        ])
        waitFor(activity.row(containing: "Casey Friend"), timeout: 15)
        XCTAssertTrue(activity.row(containing: "just joined").exists)
    }
}
