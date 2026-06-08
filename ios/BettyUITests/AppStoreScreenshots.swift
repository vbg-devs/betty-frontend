import XCTest

/// App Store screenshot generator — NOT an assertion test. It drives the app against
/// the in-process mock backend (seeded as Alex Tester, populated groups/tournament/chat)
/// and attaches full-screen captures of the marketing-worthy screens.
///
/// Skipped unless the runner sees `BETTY_SCREENSHOTS=1`, so the normal CI UI-test pass
/// never runs it. To generate, export it into xcodebuild's environment (xcodebuild
/// forwards `TEST_RUNNER_*` vars to the runner with the prefix stripped):
///
///   export TEST_RUNNER_BETTY_SCREENSHOTS=1
///   xcodebuild test -only-testing:BettyUITests/AppStoreScreenshots \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' …
///
/// then export the `.keepAlways` attachments from the resulting .xcresult bundle.
/// Capture display order is encoded in the attachment name prefix (01_, 02_, …).
///
/// Device-agnostic on purpose: iPhone renders the chrome as a bottom `tabBar`, iPadOS
/// renders it as top tab pills (no `tabBar` element), so navigation anchors on tab
/// BUTTONS and on-screen content rather than navigation bars. Browse is captured before
/// entering a group so the only tab switches happen from the dashboard, where the tabs
/// are reachable on both idioms.
final class AppStoreScreenshots: BettyUITestCase {
    private var home: HomeScreen { HomeScreen(app: app) }

    func testCaptureAppStoreScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["BETTY_SCREENSHOTS"] == "1",
            "Screenshot generator — run with TEST_RUNNER_BETTY_SCREENSHOTS=1"
        )

        launchApp()
        waitFor(staticText(containing: "ONE CHAMPION."), timeout: 30)
        waitFor(home.groupCard(named: "Sunday Legends"))
        snap("01_home")

        // Browse (discover public groups) — captured while the tabs are still reachable.
        tab("Browse").tap()
        waitFor(staticText(containing: "PLACE A BET."), timeout: 15)
        waitFor(BrowseScreen(app: app).publicGroup(named: "Open Arena"))
        snap("05_browse")
        tab("Home").tap()
        waitFor(staticText(containing: "ONE CHAMPION."), timeout: 15)

        // Open Sunday Legends → bet sheet (predict the score).
        scrollTo(home.groupCard(named: "Sunday Legends")).tap()
        let detail = GroupDetailScreen(app: app)
        waitFor(staticText(containing: "SUNDAY LEGENDS"), timeout: 15)

        scrollTo(detail.gamesTab).tap()
        let upcoming = waitFor(detail.gameCard(DefaultScenario.upcomingGameID), timeout: 15)
        upcoming.tap()
        let sheet = BetSheetScreen(app: app)
        waitFor(sheet.header)
        sheet.homePlus.tap()
        sheet.homePlus.tap()
        sheet.awayPlus.tap()
        snap("02_bet")
        sheet.closeButton.tap()
        waitForDisappearance(sheet.header)

        // Leaderboard (climb the standings).
        scrollTo(detail.leaderboardTab).tap()
        waitFor(detail.leaderboardRow(0))
        snap("03_leaderboard")

        // Group chat / meme board (talk trash) — last, so no back-navigation is needed.
        scrollTo(detail.groupTab).tap()
        let memeBoard = app.buttons["OPEN MEME BOARD →"]
        scrollTo(memeBoard).tap()
        let chat = ChatScreen(app: app)
        waitFor(chat.messageRow(1), timeout: 15)
        snap("04_chat")
    }

    /// Tab chrome entry that works on both idioms: a bottom `tabBar` button on iPhone,
    /// a plain top tab button on iPad.
    private func tab(_ name: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name].firstMatch
    }

    /// Full-device capture kept in the .xcresult for export.
    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
