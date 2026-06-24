import XCTest

/// Group chat screen (`GroupChatView`, nav title "Chat") — CHAT/ACTIVITY segments,
/// meme-board message rows, reactions, composer, and the activity ticker section.
/// Identifiers follow "chat.<screen>.<element>" (see ChatMessageRow/GroupChatView/
/// ActivityFeedRows in Betty/Features/Chat).
struct ChatScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Chat"] }

    // Segmented CHAT / ACTIVITY picker.
    var chatSegment: XCUIElement { app.buttons["CHAT"] }
    var activitySegment: XCUIElement { app.buttons["ACTIVITY"] }

    // MARK: - Message board

    /// "★ GROUP CHAT" kicker.
    var boardHeader: XCUIElement { app.staticTexts["★ GROUP CHAT"] }
    /// "<N> MESSAGES" count — only rendered when the list is non-empty.
    var messageCount: XCUIElement { element(app, id: "chat.board.count") }
    var emptyState: XCUIElement { element(app, id: "chat.board.empty") }

    func messageRow(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id)") }
    func author(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).author") }
    func timestamp(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).timestamp") }
    func body(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).body") }
    func image(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).image") }
    func avatar(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).avatar") }
    func deleteButton(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).delete") }
    func addReactionButton(_ id: Int) -> XCUIElement { element(app, id: "chat.board.message.\(id).addReaction") }
    func reactionChip(_ id: Int, emoji: String) -> XCUIElement {
        element(app, id: "chat.board.message.\(id).reaction.\(emoji)")
    }
    func pickerEmoji(_ id: Int, emoji: String) -> XCUIElement {
        element(app, id: "chat.board.message.\(id).picker.\(emoji)")
    }

    // MARK: - Composer

    var composerField: XCUIElement { app.textFields["chat.composer.field"] }
    /// "SEND" in text mode, "SEARCH" in GIF mode.
    var submitButton: XCUIElement { element(app, id: "chat.composer.submit") }
    var gifToggle: XCUIElement { element(app, id: "chat.composer.gifToggle") }
    var photoButton: XCUIElement { element(app, id: "chat.composer.photo") }

    func typeMessage(_ text: String) {
        composerField.tap()
        composerField.typeText(text)
    }

    // MARK: - GIF selector (appears above the board after a successful Giphy search)

    var gifSelectorTitle: XCUIElement { element(app, id: "chat.gifSelector.title") }
    /// The preview's accessibility VALUE carries the currently selected GIF's id.
    var gifPreview: XCUIElement { element(app, id: "chat.gifSelector.preview") }
    var selectedGifID: String? { gifPreview.value as? String }
    var gifPrevButton: XCUIElement { element(app, id: "chat.gifSelector.prev") }
    var gifNextButton: XCUIElement { element(app, id: "chat.gifSelector.next") }
    var gifSubmitButton: XCUIElement { element(app, id: "chat.gifSelector.submit") }
    var gifCancelButton: XCUIElement { element(app, id: "chat.gifSelector.cancel") }

    // MARK: - Activity section

    var activityHeader: XCUIElement { app.staticTexts["★ ACTIVITY"] }
    var activityEmptyTitle: XCUIElement { app.staticTexts["ALL QUIET."] }
    var clearAllButton: XCUIElement { element(app, id: "chat.activity.clearAll") }

    /// First activity row for a WS event type (e.g. "bet_placed").
    func activityRow(type: String) -> XCUIElement { element(app, id: "chat.activity.row.\(type)") }
    func activityKicker(type: String) -> XCUIElement {
        element(app, id: "chat.activity.row.\(type).kicker")
    }

    // MARK: - Delete confirm toast (ToastCenter confirm copy)

    var deleteConfirmText: XCUIElement {
        app.staticTexts["Delete this message? This cannot be undone."]
    }
    var confirmYesButton: XCUIElement { app.buttons["YES, DO IT →"] }
    var confirmCancelButton: XCUIElement { app.buttons["CANCEL"] }
}
