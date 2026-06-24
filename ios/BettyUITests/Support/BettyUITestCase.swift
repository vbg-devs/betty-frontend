import XCTest

/// Base class for every Betty UI test: starts a fresh `BettyMockBackend` per test,
/// launches the app with the DEBUG launch-environment overrides pointing at it, and
/// (by default) pre-authenticates via the seeded-auth fast path so tests skip sign-in.
///
/// Suite-writer surface:
/// - `makeScenario()`        — override to customize the fixture (default: DefaultScenario)
/// - `seedsAuthentication`   — override to `false` in auth-flow suites
/// - `launchApp(seedAuth:)`  — per-test override of the seeding default
/// - `backend` / `withScenario` / `pushWS` / `waitForWebSocketClient`
/// - `waitFor(_:timeout:)` / `scrollTo(_:)` element helpers
/// - automatic full-screen screenshot attachment when a test failed
class BettyUITestCase: XCTestCase {
    private(set) var backend: BettyMockBackend!
    private(set) var app: XCUIApplication!

    /// Default seeding behavior for `launchApp()`. Auth suites override to `false`.
    var seedsAuthentication: Bool { true }

    /// UID the seeded session signs in as — must exist in the scenario.
    var seededUserID: String { DefaultScenario.currentUserID }

    /// Fixture state served by the mock. Override for suite-specific scenarios; mutate
    /// later (before `launchApp()` or mid-test) via `withScenario`.
    func makeScenario() -> MockScenario { DefaultScenario.build() }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        backend = BettyMockBackend(scenario: makeScenario())
        try backend.start()
        app = XCUIApplication()
        app.launchEnvironment["BETTY_UITEST"] = "1"
        app.launchEnvironment["BETTY_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["BETTY_API_BASE_URL"] = backend.apiBaseURL.absoluteString
        app.launchEnvironment["BETTY_IDENTITY_BASE_URL"] = backend.identityBaseURL.absoluteString
        app.launchEnvironment["BETTY_SECURETOKEN_BASE_URL"] = backend.secureTokenBaseURL.absoluteString
        app.launchEnvironment["BETTY_WS_URL"] = backend.webSocketURL.absoluteString
    }

    override func tearDown() {
        if let run = testRun, run.totalFailureCount > 0, app != nil {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let log = backend.recordedRequests
                .map { "\($0.method) \($0.path) \($0.query) body=\(String(decoding: $0.body.prefix(300), as: UTF8.self))" }
                .joined(separator: "\n")
            let requestLog = XCTAttachment(string: log.isEmpty ? "(no requests recorded)" : log)
            requestLog.name = "backend-requests-\(name)"
            requestLog.lifetime = .keepAlways
            add(requestLog)
        }
        app?.terminate()
        app = nil
        backend?.stop()
        backend = nil
        super.tearDown()
    }

    /// Launches the app. `seedAuth: nil` uses the suite default (`seedsAuthentication`).
    func launchApp(seedAuth: Bool? = nil) {
        if seedAuth ?? seedsAuthentication {
            app.launchEnvironment["BETTY_SEED_REFRESH_TOKEN"] = backend.refreshToken(for: seededUserID)
            app.launchEnvironment["BETTY_SEED_UID"] = seededUserID
        } else {
            app.launchEnvironment.removeValue(forKey: "BETTY_SEED_REFRESH_TOKEN")
            app.launchEnvironment.removeValue(forKey: "BETTY_SEED_UID")
        }
        app.launch()
    }

    // MARK: - Scenario / WebSocket access

    /// Exclusive read/write access to the live mock state (visible to the next request).
    @discardableResult
    func withScenario<T>(_ body: (inout MockScenario) -> T) -> T {
        backend.withScenario(body)
    }

    /// Broadcasts a WebSocket event (`{"type": ..., "message": ...}`) to the app.
    /// Call `waitForWebSocketClient()` first — pushes before the app connects are lost.
    func pushWS(type: String, message: Any? = nil) {
        backend.pushEvent(type: type, message: message)
    }

    @discardableResult
    func waitForWebSocketClient(timeout: TimeInterval = 15,
                                file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let connected = backend.waitForWebSocketClient(timeout: timeout)
        if !connected {
            XCTFail("App never connected to the mock WebSocket server", file: file, line: line)
        }
        return connected
    }

    /// iOS presents the AutoFill "Save Password?" sheet after a successful interactive
    /// sign-in/up, and it swallows every tap until dismissed. It is a remote view
    /// hosted by another process but MERGED into the app's accessibility tree (same
    /// hierarchy, foreign pid) — so query it through the app proxy, not Springboard.
    func dismissSavePasswordPromptIfPresent(timeout: TimeInterval = 4) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: timeout) {
            notNow.tap()
            waitForDisappearance(notNow, timeout: 5)
        }
    }

    /// Dismisses the keyboard via the form's DONE accessory ("keyboard.done"). Swiping
    /// it away instead is a trap: app-level swipes start inside the keyboard frame
    /// and get typed as key presses (a number pad has no return key), while content
    /// drags can reach the scroll top and become the sheet's pull-to-dismiss.
    func dismissKeyboardIfPresent(file: StaticString = #filePath, line: UInt = #line) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let done = app.buttons["keyboard.done"].firstMatch
        if !done.waitForExistence(timeout: 3) {
            XCTFail("Keyboard is up but the DONE accessory is missing", file: file, line: line)
            return
        }
        done.tap()
        waitForDisappearance(keyboard, timeout: 5, file: file, line: line)
    }

    // MARK: - Element helpers

    /// Asserts the element exists within `timeout` and returns it for chaining.
    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10,
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        if !element.waitForExistence(timeout: timeout) {
            XCTFail("Timed out waiting for element: \(element)", file: file, line: line)
        }
        return element
    }

    /// Waits for the element to disappear (sheet dismissals, splash → content).
    func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 10,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Element did not disappear: \(element)", file: file, line: line)
        }
    }

    /// Swipes up on `container` (default: the app) until `element` exists — SwiftUI lazy
    /// stacks only materialize rows near the viewport.
    @discardableResult
    func scrollTo(_ element: XCUIElement, in container: XCUIElement? = nil,
                  maxSwipes: Int = 6, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let surface = container ?? app!
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return element }
            surface.swipeUp(velocity: .slow)
        }
        if !element.exists {
            XCTFail("Element not found after scrolling: \(element)", file: file, line: line)
        }
        return element
    }

    /// First static text whose label CONTAINS the fragment (concatenated SwiftUI Texts
    /// render as a single element — exact matches are brittle).
    func staticText(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}
