import XCTest

// Home-area page-object surface on top of the shared `HomeScreen` in Screens.swift.
// Identifier convention: "home.<screen>.<element>" — the identifiers live in
// Betty/Features/Home (HomeView / HomeNeedActionSection / HomeGroupCards).
extension HomeScreen {
    // MARK: Hero

    var heroHeadline: XCUIElement { element(app, id: "home.hero.headline") }
    var heroCountdown: XCUIElement { element(app, id: "home.hero.countdown") }
    var heroNewGroupButton: XCUIElement { element(app, id: "home.hero.newGroup") }
    var heroBrowseButton: XCUIElement { element(app, id: "home.hero.browsePublic") }

    // MARK: Feedback banner

    var feedbackBanner: XCUIElement { element(app, id: "home.feedback.banner") }

    // MARK: Need-action banner

    var needActionHeader: XCUIElement { element(app, id: "home.needAction.header") }

    func needActionRow(_ gameID: Int) -> XCUIElement {
        element(app, id: "home.needAction.row.\(gameID)")
    }

    // MARK: Running/Ended tabs + grouping toggle

    var runningTabButton: XCUIElement { element(app, id: "home.tabs.running") }
    var endedTabButton: XCUIElement { element(app, id: "home.tabs.ended") }
    var groupedToggle: XCUIElement { element(app, id: "home.tabs.grouped") }
    var listToggle: XCUIElement { element(app, id: "home.tabs.list") }
    var tabEmptyCopy: XCUIElement { element(app, id: "home.tabs.emptyCopy") }

    // MARK: Group cards

    func groupCardLink(_ groupID: Int) -> XCUIElement {
        element(app, id: "home.groups.card.\(groupID)")
    }

    func stackRow(_ groupID: Int) -> XCUIElement {
        element(app, id: "home.groups.stackRow.\(groupID)")
    }

    func stackCountPill(tournamentID: Int) -> XCUIElement {
        element(app, id: "home.groups.stack.count.\(tournamentID)")
    }

    // MARK: Empty / failure states

    var emptyHeadline: XCUIElement { element(app, id: "home.empty.headline") }
    var emptyStartGroupButton: XCUIElement { element(app, id: "home.empty.startGroup") }
    var emptyJoinPublicButton: XCUIElement { element(app, id: "home.empty.joinPublic") }
    var loadFailedRetryButton: XCUIElement { element(app, id: "home.loadFailed.retry") }

    // MARK: Helpers

    /// Case-insensitive copy lookup — `.textCase(.uppercase)` styling means rendered
    /// labels may differ in case from the source strings.
    func text(containingIgnoringCase fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }
}
