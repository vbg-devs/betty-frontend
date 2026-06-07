import XCTest

/// Chat coverage gaps beyond `ChatE2ETests`: the full GIF send flow — Giphy search
/// against the mock backend (`BETTY_GIPHY_BASE_URL` override), the selector logic
/// (opens at index 0, PREV/NEXT clamped, CANCEL resets, query kept on failure), and
/// the actual `POST /messageboard {group_id, image_url}` of the chosen GIF.
///
/// Uses "Office Royale" (group 2, no fixture messages) so the selector card is fully
/// on-screen above the empty board.
final class ChatMoreE2ETests: BettyUITestCase {
    private var chat: ChatScreen { ChatScreen(app: app) }

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Point the app's GiphyClient at the mock backend (DEBUG-only override).
        app.launchEnvironment["BETTY_GIPHY_BASE_URL"] = backend.httpBase
    }

    // MARK: - Helpers

    private func openChat(groupNamed name: String = "Office Royale") {
        let home = HomeScreen(app: app)
        waitFor(TabBarScreen(app: app).home, timeout: 30)
        waitFor(home.navigationBar, timeout: 15)
        scrollTo(home.groupCard(named: name)).tap()
        let chatLink = app.buttons["OPEN MEME BOARD →"]
        scrollTo(chatLink, maxSwipes: 12).tap()
        waitFor(chat.navigationBar, timeout: 10)
    }

    /// Registers (or overrides — last registration wins) the Giphy search route.
    private func stubGiphySearch(ids: [String]) {
        let response = MockHTTPResponse.json(GiphyFixtures.searchResponse(ids: ids, httpBase: backend.httpBase))
        backend.http.route("GET", "/v1/gifs/search") { _, _ in response }
    }

    /// Flips the composer into GIF mode (same dead-tap retry as ChatE2ETests).
    private func enableGifMode() {
        waitFor(chat.gifToggle).tap()
        if !chat.submitButton.label.contains("SEARCH") {
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'SEARCH'"),
                                                object: chat.submitButton)],
                timeout: 3)
            if !chat.submitButton.label.contains("SEARCH") {
                chat.gifToggle.tap()
            }
        }
        waitForLabel(of: chat.submitButton, containing: "SEARCH")
    }

    /// GIF mode + type query + tap SEARCH.
    private func searchGifs(_ query: String) {
        enableGifMode()
        chat.typeMessage(query)
        chat.submitButton.tap()
    }

    private func waitForLabel(of element: XCUIElement, containing fragment: String,
                              timeout: TimeInterval = 10,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND label CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Label never contained '\(fragment)' (last: \(element.exists ? element.label : "<gone>"))",
                    file: file, line: line)
        }
    }

    /// Waits until the preview's accessibility value (the selected GIF's id) matches.
    private func waitForSelectedGif(_ id: String, timeout: TimeInterval = 10,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND value == %@", id)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: chat.gifPreview)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Selected GIF never became '\(id)' (last: \(chat.selectedGifID ?? "<none>"))",
                    file: file, line: line)
        }
    }

    @discardableResult
    private func waitForBackendRequests(method: String, pathPrefix: String, count: Int = 1,
                                        timeout: TimeInterval = 10,
                                        file: StaticString = #filePath, line: UInt = #line) -> [MockHTTPRequest] {
        let predicate = NSPredicate { [backend] _, _ in
            (backend?.requests(method: method, pathPrefix: pathPrefix).count ?? 0) >= count
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
        let recorded = backend.requests(method: method, pathPrefix: pathPrefix)
        XCTAssertGreaterThanOrEqual(recorded.count, count,
                                    "expected \(count)+ \(method) \(pathPrefix) requests",
                                    file: file, line: line)
        return recorded
    }

    // MARK: - GIF search → selector

    /// SEARCH issues GET /v1/gifs/search (api_key + q + limit=10) against the override
    /// host; the selector opens on the FIRST result with PREV disabled and the query
    /// cleared (web parity: cleared on success).
    func testGifSearchOpensSelectorAtFirstResult() {
        stubGiphySearch(ids: GiphyFixtures.gifIDs)
        launchApp()
        openChat()

        searchGifs("goal")

        waitFor(chat.gifSelectorTitle)
        waitForSelectedGif("g0")
        XCTAssertFalse(chat.gifPrevButton.isEnabled, "PREV disabled at index 0")
        XCTAssertTrue(chat.gifNextButton.isEnabled, "NEXT enabled with more results")

        let gets = waitForBackendRequests(method: "GET", pathPrefix: "/v1/gifs/search")
        XCTAssertEqual(gets.first?.query["q"], "goal")
        XCTAssertEqual(gets.first?.query["limit"], "10")
        XCTAssertEqual(gets.first?.query["api_key"]?.isEmpty, false, "api_key must be sent")
        XCTAssertNotEqual(chat.composerField.value as? String, "goal",
                          "query clears after a successful search")
    }

    /// PREV/NEXT walk the results and clamp at both ends (buttons disable at the bounds).
    func testGifSelectorNextPrevClampAtBounds() {
        stubGiphySearch(ids: GiphyFixtures.gifIDs)
        launchApp()
        openChat()
        searchGifs("clamp")
        waitForSelectedGif("g0")

        waitFor(chat.gifNextButton).tap()
        waitForSelectedGif("g1")
        XCTAssertTrue(chat.gifPrevButton.isEnabled)

        chat.gifNextButton.tap()
        waitForSelectedGif("g2")
        XCTAssertFalse(chat.gifNextButton.isEnabled, "NEXT disabled at the last result")
        XCTAssertTrue(chat.gifPrevButton.isEnabled)

        chat.gifPrevButton.tap()
        waitForSelectedGif("g1")
        chat.gifPrevButton.tap()
        waitForSelectedGif("g0")
        XCTAssertFalse(chat.gifPrevButton.isEnabled, "PREV disabled back at index 0")
        XCTAssertTrue(chat.gifNextButton.isEnabled)
    }

    /// CANCEL closes the selector and resets the index — the next search reopens at the
    /// first result. Nothing is ever posted.
    func testGifCancelResetsSelectorAndNextSearchOpensAtFirst() {
        stubGiphySearch(ids: GiphyFixtures.gifIDs)
        launchApp()
        openChat()
        searchGifs("first")
        waitForSelectedGif("g0")
        waitFor(chat.gifNextButton).tap()
        waitForSelectedGif("g1")

        waitFor(chat.gifCancelButton).tap()
        waitForDisappearance(chat.gifSelectorTitle)

        chat.typeMessage("second")
        chat.submitButton.tap()
        waitFor(chat.gifSelectorTitle)
        waitForSelectedGif("g0") // gifIndex reset by CANCEL, not stuck at 1

        let posts = backend.requests(method: "POST", pathPrefix: "/api/v1/messageboard")
        XCTAssertTrue(posts.isEmpty, "browsing/cancelling must never POST a message")
    }

    // MARK: - GIF submit → POST /messageboard

    /// SUBMIT posts the CHOSEN (not first) GIF: POST /messageboard {group_id, image_url}
    /// with body omitted; the echo renders as an image-only message and the selector
    /// closes.
    func testGifSubmitPostsChosenGifAsImageMessage() {
        stubGiphySearch(ids: GiphyFixtures.gifIDs)
        launchApp()
        openChat()
        searchGifs("winner")
        waitForSelectedGif("g0")
        waitFor(chat.gifNextButton).tap()
        waitForSelectedGif("g1")

        waitFor(chat.gifSubmitButton).tap()

        // nextMessageID starts at 1000 in the mock.
        waitFor(chat.messageRow(1000))
        waitFor(chat.image(1000))
        XCTAssertFalse(chat.body(1000).exists, "a GIF message renders ONLY the image")
        waitForDisappearance(chat.gifSelectorTitle)
        waitForLabel(of: chat.messageCount, containing: "1 MESSAGES")

        let posts = waitForBackendRequests(method: "POST", pathPrefix: "/api/v1/messageboard")
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].bodyJSON?["group_id"] as? Int, DefaultScenario.groupOfficeRoyaleID)
        XCTAssertEqual(posts[0].bodyJSON?["image_url"] as? String,
                       GiphyFixtures.gifURL("g1", httpBase: backend.httpBase),
                       "the SELECTED gif's original URL must be posted")
        XCTAssertNil(posts[0].bodyJSON?["body"], "nil body must be omitted (web parity)")
    }

    /// A failed POST keeps the selector open (and the selection) so SUBMIT can be
    /// retried; nothing is appended to the board.
    func testGifSubmitFailureKeepsSelectorOpenForRetry() {
        stubGiphySearch(ids: GiphyFixtures.gifIDs)
        launchApp()
        openChat()
        backend.http.route("POST", "/api/v1/messageboard") { _, _ in .empty(500) }
        searchGifs("retry")
        waitForSelectedGif("g0")

        waitFor(chat.gifSubmitButton).tap()
        waitForBackendRequests(method: "POST", pathPrefix: "/api/v1/messageboard")

        // isPosting flips back off — the selector survives the failure for a retry.
        let enabled = NSPredicate(format: "exists == true AND enabled == true")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled,
                                                             object: chat.gifSubmitButton)],
                             timeout: 10)
        XCTAssertTrue(chat.gifSelectorTitle.exists, "selector stays open after a failed post")
        waitForSelectedGif("g0")
        XCTAssertFalse(chat.messageRow(1000).waitForExistence(timeout: 2),
                       "failed post must not append a message")

        chat.gifSubmitButton.tap() // retry is possible — a second POST goes out
        waitForBackendRequests(method: "POST", pathPrefix: "/api/v1/messageboard", count: 2)
    }

    // MARK: - Search failure / empty results

    /// A failed Giphy search keeps the typed query (web parity) so retrying the SEARCH
    /// — once Giphy recovers — opens the selector without retyping.
    func testGifSearchFailureKeepsQueryAndRetryWorks() {
        backend.http.route("GET", "/v1/gifs/search") { _, _ in .empty(500) }
        launchApp()
        openChat()

        searchGifs("oops")

        waitForBackendRequests(method: "GET", pathPrefix: "/v1/gifs/search")
        waitForLabel(of: chat.submitButton, containing: "SEARCH") // isSearching done, still GIF mode
        XCTAssertFalse(chat.gifSelectorTitle.exists, "no selector on a failed search")
        XCTAssertEqual(chat.composerField.value as? String, "oops",
                       "query is kept after a failed search")

        stubGiphySearch(ids: GiphyFixtures.gifIDs) // Giphy "recovers" (last route wins)
        chat.submitButton.tap()

        waitFor(chat.gifSelectorTitle)
        waitForSelectedGif("g0")
        waitForBackendRequests(method: "GET", pathPrefix: "/v1/gifs/search", count: 2)
    }

    /// Zero hits: the query still clears (web parity) and no selector opens.
    func testGifSearchWithZeroHitsClearsQueryWithoutSelector() {
        stubGiphySearch(ids: [])
        launchApp()
        openChat()

        searchGifs("nothing")

        waitForBackendRequests(method: "GET", pathPrefix: "/v1/gifs/search")
        let cleared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", "nothing"),
            object: chat.composerField)
        XCTAssertEqual(XCTWaiter().wait(for: [cleared], timeout: 10), .completed,
                       "query clears even when the search has zero hits")
        XCTAssertFalse(chat.gifSelectorTitle.exists, "no selector for zero hits")
        waitForLabel(of: chat.submitButton, containing: "SEARCH") // GIF mode is kept
    }
}
