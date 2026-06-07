import XCTest

/// E2E suite for the chat area: meme-board rendering (avatars, timestamps, image
/// messages), sending, emoji reactions with grouped counts, message deletion, the
/// 10 s poll, and the activity-feed row variants fed by live WebSocket events
/// (`GroupChatView` + `ChatMessageRow` + `ActivityFeedRows`).
final class ChatE2ETests: BettyUITestCase {
    private var chat: ChatScreen { ChatScreen(app: app) }

    // MARK: - Navigation

    /// Home → group card → group detail (GROUP tab) → "OPEN MEME BOARD →" push.
    private func openChat(groupNamed name: String = "Sunday Legends") {
        let home = HomeScreen(app: app)
        waitFor(TabBarScreen(app: app).home, timeout: 30)
        waitFor(home.navigationBar, timeout: 15)
        scrollTo(home.groupCard(named: name)).tap()
        let chatLink = app.buttons["OPEN MEME BOARD →"]
        scrollTo(chatLink, maxSwipes: 12).tap()
        waitFor(chat.navigationBar, timeout: 10)
    }

    private func openActivitySection() {
        openChat()
        waitFor(chat.activitySegment).tap()
        waitFor(chat.activityEmptyTitle) // feed starts empty (live-only + pings filtered)
        waitForWebSocketClient()
    }

    // MARK: - Wait helpers

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

    /// Waits until the backend recorded at least `count` matching requests, then
    /// returns them (UI updates can land before the recorder is queried).
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

    // MARK: - Message list rendering

    /// GET /messageboard/:groupid is fetched (amount=50, offset=0 — page index) and the
    /// rows render author names, relative timestamps, and avatar initials.
    func testChatListRendersAuthorsTimestampsAndAvatars() {
        launchApp()
        openChat()

        waitFor(chat.messageRow(1))
        waitFor(chat.messageRow(2))
        XCTAssertEqual(chat.author(1).label, "Casey Friend")
        XCTAssertEqual(chat.author(2).label, "Alex Tester")
        XCTAssertTrue(chat.timestamp(1).label.contains("ago"), "relative timestamp expected")
        XCTAssertTrue(chat.timestamp(2).label.contains("ago"), "relative timestamp expected")
        // Avatar initials: first letters of first + second word, uppercased.
        XCTAssertTrue(chat.messageRow(1).staticTexts["CF"].exists, "Casey Friend avatar initials")
        XCTAssertTrue(chat.messageRow(2).staticTexts["AT"].exists, "Alex Tester avatar initials")
        XCTAssertTrue(chat.boardHeader.exists)
        waitForLabel(of: chat.messageCount, containing: "2 MESSAGES")

        let gets = waitForBackendRequests(method: "GET", pathPrefix: "/api/v1/messageboard/1")
        XCTAssertEqual(gets.first?.query["amount"], "50")
        XCTAssertEqual(gets.first?.query["offset"], "0")
    }

    /// Server order is newest-first; the screen reverses it so the newest message
    /// renders at the bottom (web column-reverse parity).
    func testChatListShowsNewestMessageAtBottom() {
        launchApp()
        openChat()

        let older = waitFor(chat.messageRow(1)) // -2 h
        let newer = waitFor(chat.messageRow(2)) // -1 h
        XCTAssertLessThan(older.frame.minY, newer.frame.minY,
                          "older message must render above the newer one")
    }

    /// An image message renders ONLY the image (no body text).
    func testChatRendersImageMessage() {
        withScenario { $0.messages.append(ChatFixtures.imageMessage(publicAssetBase: backend.publicAssetBase)) }
        launchApp()
        openChat()

        waitFor(chat.messageRow(ChatFixtures.imageMessageID))
        waitFor(chat.image(ChatFixtures.imageMessageID))
        XCTAssertFalse(chat.body(ChatFixtures.imageMessageID).exists,
                       "image message must not render a text body")
    }

    /// Author display is `nickname ?? name ?? "Unknown"` (empty strings count as missing).
    func testChatUsesNicknameAndUnknownAuthorFallbacks() {
        withScenario {
            $0.messages.append(ChatFixtures.nicknameMessage())
            $0.messages.append(ChatFixtures.unknownAuthorMessage())
        }
        launchApp()
        openChat()

        waitFor(chat.messageRow(ChatFixtures.nicknameMessageID))
        XCTAssertEqual(chat.author(ChatFixtures.nicknameMessageID).label, "The Oracle")
        XCTAssertEqual(chat.author(ChatFixtures.unknownAuthorMessageID).label, "Unknown")
    }

    /// Empty board: placeholder text shows and the "<N> MESSAGES" header is hidden.
    func testEmptyChatShowsPlaceholderAndHidesCount() {
        launchApp()
        openChat(groupNamed: "Office Royale") // no fixture messages in group 2

        waitFor(chat.emptyState)
        XCTAssertTrue(chat.boardHeader.exists)
        XCTAssertFalse(chat.messageCount.exists, "count header hidden when empty")
    }

    // MARK: - Sending

    /// SEND → POST /messageboard {group_id, body} (image_url omitted), 201 echo with
    /// reactions:null is appended, input clears, count header updates.
    func testSendMessagePostsAndAppendsToList() {
        launchApp()
        openChat()
        waitFor(chat.messageRow(2))

        chat.typeMessage("Hello from e2e")
        chat.submitButton.tap()

        // nextMessageID starts at 1000 in the mock.
        waitFor(chat.messageRow(1000))
        XCTAssertEqual(chat.body(1000).label, "Hello from e2e")
        XCTAssertTrue(chat.addReactionButton(1000).exists, "reactions:null normalizes to []")
        waitForLabel(of: chat.messageCount, containing: "3 MESSAGES")
        XCTAssertNotEqual(chat.composerField.value as? String, "Hello from e2e",
                          "input clears after a successful send")

        let posts = waitForBackendRequests(method: "POST", pathPrefix: "/api/v1/messageboard")
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].bodyJSON?["group_id"] as? Int, DefaultScenario.groupSundayLegendsID)
        XCTAssertEqual(posts[0].bodyJSON?["body"] as? String, "Hello from e2e")
        XCTAssertNil(posts[0].bodyJSON?["image_url"], "nil image_url must be omitted (web parity)")
    }

    /// A failed POST keeps the typed draft so the user can retry (web parity: log only).
    func testSendFailureKeepsDraftForRetry() {
        launchApp()
        openChat()
        waitFor(chat.messageRow(2))
        backend.http.route("POST", "/api/v1/messageboard") { _, _ in .empty(500) }

        chat.typeMessage("Boom retry")
        chat.submitButton.tap()

        waitForBackendRequests(method: "POST", pathPrefix: "/api/v1/messageboard")
        XCTAssertFalse(chat.messageRow(1000).waitForExistence(timeout: 2),
                       "failed send must not append a message")
        XCTAssertEqual(chat.composerField.value as? String, "Boom retry",
                       "draft is kept after a failed send")
    }

    /// Submit stays disabled until a draft exists; the photo attachment entry point is
    /// present (PhotosPicker itself is an OS sheet — boundary only).
    func testComposerSubmitDisabledUntilDraftEntered() {
        launchApp()
        openChat()

        waitFor(chat.submitButton)
        XCTAssertFalse(chat.submitButton.isEnabled, "SEND disabled with an empty draft")
        XCTAssertTrue(chat.photoButton.exists)
        XCTAssertTrue(chat.photoButton.isEnabled)
        chat.typeMessage("x")
        XCTAssertTrue(chat.submitButton.isEnabled)
    }

    /// GIF toggle flips the composer into Giphy search mode and back (search itself
    /// hits the real Giphy API — boundary only, no search triggered).
    func testGifToggleSwitchesComposerToSearchMode() {
        launchApp()
        openChat()

        waitFor(chat.gifToggle).tap()
        // A tap during composer layout can land dead — re-tap once if the mode
        // didn't flip (the state change is immediate with animations disabled).
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
        XCTAssertEqual(chat.composerField.placeholderValue, "Search Giphy…")
        chat.gifToggle.tap()
        waitForLabel(of: chat.submitButton, containing: "SEND")
        XCTAssertEqual(chat.composerField.placeholderValue, "Send message to group")
    }

    // MARK: - Reactions

    /// Chips group by emoji in first-seen order of the reactions array with counts.
    func testReactionsRenderGroupedCountsInFirstSeenOrder() {
        withScenario { $0.messages.append(ChatFixtures.groupedReactionsMessage()) }
        launchApp()
        openChat()

        let id = ChatFixtures.groupedReactionsMessageID
        waitFor(chat.messageRow(id))
        let thumbs = waitFor(chat.reactionChip(id, emoji: "👍"))
        let heart = waitFor(chat.reactionChip(id, emoji: "❤️"))
        waitForLabel(of: thumbs, containing: "2")
        waitForLabel(of: heart, containing: "1")
        XCTAssertLessThan(thumbs.frame.minX, heart.frame.minX,
                          "👍 was seen first in the reactions array")
    }

    /// "+" picker → emoji → PUT /messageboard/:id/reaction {emoji_id} → chip appears.
    func testAddReactionViaPicker() {
        launchApp()
        openChat()

        waitFor(chat.addReactionButton(2)).tap()
        waitFor(chat.pickerEmoji(2, emoji: "👍")).tap()

        waitFor(chat.reactionChip(2, emoji: "👍"))
        waitForLabel(of: chat.reactionChip(2, emoji: "👍"), containing: "1")
        let puts = waitForBackendRequests(method: "PUT", pathPrefix: "/api/v1/messageboard/2/reaction")
        XCTAssertEqual(puts[0].bodyJSON?["emoji_id"] as? String, "👍")
        XCTAssertFalse(chat.pickerEmoji(2, emoji: "👍").exists, "picker closes after picking")
    }

    /// Tapping the chip of my current emoji removes my reaction (DELETE, optimistic).
    func testRemoveOwnReactionByTappingChip() {
        launchApp()
        openChat()

        // DefaultScenario: message 1 carries my "+1" reaction.
        waitFor(chat.reactionChip(1, emoji: "+1")).tap()

        waitForDisappearance(chat.reactionChip(1, emoji: "+1"))
        waitForBackendRequests(method: "DELETE", pathPrefix: "/api/v1/messageboard/1/reaction")
    }

    /// Tapping a different emoji replaces my reaction (one per user per message):
    /// my ❤️ disappears and 👍 takes over my vote.
    func testTappingDifferentEmojiReplacesMyReaction() {
        withScenario { $0.messages.append(ChatFixtures.groupedReactionsMessage()) }
        launchApp()
        openChat()

        let id = ChatFixtures.groupedReactionsMessageID
        waitFor(chat.reactionChip(id, emoji: "👍")).tap()

        waitForDisappearance(chat.reactionChip(id, emoji: "❤️"))
        waitForLabel(of: chat.reactionChip(id, emoji: "👍"), containing: "3")
        let puts = waitForBackendRequests(method: "PUT",
                                          pathPrefix: "/api/v1/messageboard/\(id)/reaction")
        XCTAssertEqual(puts[0].bodyJSON?["emoji_id"] as? String, "👍")
    }

    /// A failed PUT rolls the optimistic chip back (web parity: log only, restore list).
    func testReactionRollsBackWhenServerFails() {
        launchApp()
        openChat()
        backend.http.route("PUT", "/api/v1/messageboard/2/reaction") { _, _ in .empty(500) }

        waitFor(chat.addReactionButton(2)).tap()
        waitFor(chat.pickerEmoji(2, emoji: "🔥")).tap()

        waitForBackendRequests(method: "PUT", pathPrefix: "/api/v1/messageboard/2/reaction")
        waitForDisappearance(chat.reactionChip(2, emoji: "🔥"))
    }

    /// The picker shows the fixed 8-emoji palette, toggles closed on a second tap, and
    /// only one picker is open at a time.
    func testReactionPickerPaletteAndSingleOpenSemantics() {
        launchApp()
        openChat()

        waitFor(chat.addReactionButton(1)).tap()
        for emoji in ["👍", "❤️", "😂", "🔥", "🎉", "😮", "😢", "👀"] {
            XCTAssertTrue(chat.pickerEmoji(1, emoji: emoji).exists, "palette missing \(emoji)")
        }

        chat.addReactionButton(1).tap() // toggle closed
        waitForDisappearance(chat.pickerEmoji(1, emoji: "👍"))

        chat.addReactionButton(1).tap()
        waitFor(chat.pickerEmoji(1, emoji: "👍"))
        chat.addReactionButton(2).tap() // opening another closes the first
        waitFor(chat.pickerEmoji(2, emoji: "👍"))
        waitForDisappearance(chat.pickerEmoji(1, emoji: "👍"))
    }

    // MARK: - Deleting

    /// Only my own messages expose the delete affordance.
    func testDeleteButtonOnlyOnOwnMessages() {
        launchApp()
        openChat()

        waitFor(chat.messageRow(1))
        XCTAssertTrue(chat.deleteButton(2).exists, "own message (uid-alex) is deletable")
        XCTAssertFalse(chat.deleteButton(1).exists, "Casey's message must not be deletable")
    }

    /// Delete → pinned confirm copy → YES → DELETE /messageboard/:id, row drops,
    /// count header updates.
    func testDeleteOwnMessageAfterConfirm() {
        launchApp()
        openChat()

        waitFor(chat.deleteButton(2)).tap()
        waitFor(chat.deleteConfirmText)
        chat.confirmYesButton.tap()

        waitForDisappearance(chat.messageRow(2))
        waitForLabel(of: chat.messageCount, containing: "1 MESSAGES")
        let deletes = waitForBackendRequests(method: "DELETE", pathPrefix: "/api/v1/messageboard/2")
            .filter { $0.path == "/api/v1/messageboard/2" }
        XCTAssertEqual(deletes.count, 1)
    }

    /// CANCEL dismisses without deleting anything.
    func testDeleteCancelKeepsMessage() {
        launchApp()
        openChat()

        waitFor(chat.deleteButton(2)).tap()
        waitFor(chat.deleteConfirmText)
        chat.confirmCancelButton.tap()

        waitForDisappearance(chat.deleteConfirmText)
        XCTAssertTrue(chat.messageRow(2).exists)
        let deletes = backend.recordedRequests
            .filter { $0.method == "DELETE" && $0.path == "/api/v1/messageboard/2" }
        XCTAssertTrue(deletes.isEmpty, "CANCEL must not issue a DELETE")
    }

    /// A 404 on delete means "already gone": the message drops locally with NO error
    /// alert (pinned web behavior).
    func testDelete404DropsMessageSilently() {
        launchApp()
        openChat()

        waitFor(chat.deleteButton(2)).tap()
        waitFor(chat.deleteConfirmText)
        // Someone else (or another device) deleted it server-side meanwhile.
        withScenario { scenario in
            if let index = scenario.messages.firstIndex(where: { $0.id == 2 }) {
                scenario.messages[index].deleted = true
            }
        }
        chat.confirmYesButton.tap()

        waitForDisappearance(chat.messageRow(2))
        XCTAssertFalse(app.staticTexts["Could not delete message"].exists,
                       "404 must be silent — the message is simply gone")
    }

    // MARK: - Live updates

    /// A message appended server-side surfaces through the 10 s poll with no user action.
    func testIncomingMessageAppearsViaPolling() {
        launchApp()
        openChat()
        waitFor(chat.messageRow(2))

        withScenario { $0.messages.append(ChatFixtures.polledMessage()) }

        waitFor(chat.messageRow(ChatFixtures.polledMessageID), timeout: 25)
        XCTAssertEqual(chat.body(ChatFixtures.polledMessageID).label, "Fresh from the server")
        waitForLabel(of: chat.messageCount, containing: "3 MESSAGES")
    }

    // MARK: - Activity feed (WS event row variants)

    /// `group_joined` (member joined) appears live in the ticker without any refresh.
    func testActivityShowsMemberJoinedLiveWithoutRefresh() {
        launchApp()
        openActivitySection()

        pushWS(type: "group_joined", message: [
            "group": ["id": DefaultScenario.groupSundayLegendsID, "name": "Sunday Legends"],
            "who": "Casey Friend",
        ])

        waitFor(chat.activityRow(type: "group_joined"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "group_joined").label, "● JOINED GROUP")
        XCTAssertTrue(staticText(containing: "Casey Friend just joined Sunday Legends").exists)
        XCTAssertTrue(chat.clearAllButton.exists)
        XCTAssertFalse(chat.activityEmptyTitle.exists)
    }

    /// `bet_placed` / `bet_updated` rows lazily load the game and render the bet copy.
    func testActivityRendersBetPlacedAndBetUpdated() {
        launchApp()
        openActivitySection()

        pushWS(type: "bet_placed", message: MockWire.betEcho(
            userID: DefaultScenario.friendUserID,
            gameID: DefaultScenario.upcomingGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            home: 2, away: 1, isUniversal: false
        ))
        pushWS(type: "bet_updated", message: MockWire.bet(MockBet(
            id: 77,
            userID: DefaultScenario.friendUserID,
            gameID: DefaultScenario.upcomingGameID,
            groupID: DefaultScenario.groupSundayLegendsID,
            homeTeamScore: 3, awayTeamScore: 1
        )))

        waitFor(staticText(containing: "Someone placed a bet on"), timeout: 15)
        waitFor(staticText(containing: "Someone updated their bet on"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "bet_placed").label, "● NEW BET")
        XCTAssertEqual(chat.activityKicker(type: "bet_updated").label, "● BET UPDATED")
    }

    /// `group_visibility_changed` resolves the cached group name and the public/private
    /// state from `public_at`.
    func testActivityRendersVisibilityChanged() {
        launchApp()
        openActivitySection()

        pushWS(type: "group_visibility_changed", message: [
            "group_id": DefaultScenario.groupSundayLegendsID,
            "public_at": MockWire.time(Date()),
        ])
        waitFor(staticText(containing: "Sunday Legends is now public"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "group_visibility_changed").label, "● VISIBILITY")

        pushWS(type: "group_visibility_changed", message: [
            "group_id": DefaultScenario.groupSundayLegendsID,
            "public_at": NSNull(),
        ])
        waitFor(staticText(containing: "Sunday Legends is now private"), timeout: 15)
    }

    /// `evaluate_game` (game message row) shows "Game evaluated" + the game's final score.
    func testActivityRendersGameEvaluated() {
        launchApp()
        openActivitySection()

        pushWS(type: "evaluate_game", message: [
            "game_id": DefaultScenario.finishedGameID,
            "home_team_score": 2,
            "away_team_score": 1,
        ])

        waitFor(chat.activityRow(type: "evaluate_game"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "evaluate_game").label, "★ FULL TIME")
        waitFor(staticText(containing: "Game evaluated"), timeout: 15)
        waitFor(staticText(containing: "2 - 1"), timeout: 15) // lazily loaded game score
    }

    /// `user_exact_score` switches copy depending on whether I am among the winners.
    func testActivityRendersExactScoreVariants() {
        launchApp()
        openActivitySection()

        pushWS(type: "user_exact_score", message: [
            "game_id": DefaultScenario.finishedGameID,
            "user_ids": [DefaultScenario.currentUserID, DefaultScenario.friendUserID],
        ])
        waitFor(staticText(containing: "You and 1 other(s) had the exact score"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "user_exact_score").label, "★ EXACT SCORE")

        pushWS(type: "user_exact_score", message: [
            "game_id": DefaultScenario.finishedGameID,
            "user_ids": [DefaultScenario.friendUserID, DefaultScenario.rivalUserID],
        ])
        waitFor(staticText(containing: "2 players had the exact score!"), timeout: 15)
    }

    /// Kickoff (capital-G "Games" key), welcome, and the two static row variants —
    /// rendered in insertion order (oldest first).
    func testActivityRendersKickoffWelcomeAndStaticRows() {
        launchApp()
        openActivitySection()

        pushWS(type: "game_starting_soon", message: [
            "Games": [["id": DefaultScenario.upcomingGameID,
                       "start_date": MockWire.time(Date().addingTimeInterval(900))]],
        ])
        pushWS(type: "user_register", message: MockWire.user(
            MockUser(id: "uid-new", email: "nova@betty.test", name: "Nova Newcomer")
        ))
        pushWS(type: "group_left")
        pushWS(type: "group_created")

        waitFor(staticText(containing: "Match is about to start"), timeout: 15)
        waitFor(staticText(containing: "Nova Newcomer just joined Betty"), timeout: 15)
        waitFor(staticText(containing: "Someone just left a group"), timeout: 15)
        waitFor(staticText(containing: "New group on Betty"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "game_starting_soon").label, "● KICKING OFF")
        XCTAssertEqual(chat.activityKicker(type: "user_register").label, "★ WELCOME")
        XCTAssertEqual(chat.activityKicker(type: "group_left").label, "● LEFT GROUP")
        XCTAssertEqual(chat.activityKicker(type: "group_created").label, "★ NEW GROUP")
        XCTAssertLessThan(chat.activityRow(type: "group_left").frame.minY,
                          chat.activityRow(type: "group_created").frame.minY,
                          "rows render in insertion order, oldest first")
    }

    /// Unknown event types degrade to the uppercased raw type + plain body.
    func testActivityRendersUnknownEventFallback() {
        launchApp()
        openActivitySection()

        pushWS(type: "season_recap")

        waitFor(chat.activityRow(type: "season_recap"), timeout: 15)
        XCTAssertEqual(chat.activityKicker(type: "season_recap").label, "SEASON_RECAP")
        XCTAssertTrue(app.staticTexts["season_recap"].exists, "body shows the raw type")
    }

    /// CLEAR ALL empties the ticker and restores the ALL QUIET placeholder.
    func testActivityClearAllRestoresEmptyState() {
        launchApp()
        openActivitySection()

        pushWS(type: "group_created")
        waitFor(chat.activityRow(type: "group_created"), timeout: 15)

        chat.clearAllButton.tap()

        waitFor(chat.activityEmptyTitle)
        XCTAssertFalse(chat.activityRow(type: "group_created").exists)
        XCTAssertFalse(chat.clearAllButton.exists, "header controls hidden when empty")
    }
}
