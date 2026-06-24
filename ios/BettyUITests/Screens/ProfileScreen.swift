import XCTest

// Page objects for the Profile area: the edit-profile tab, the global leaderboard tab,
// and the Support / About / Privacy / Admin destinations pushed from Profile.
// Identifier convention: "profile.<screen>.<element>" / "leaderboard.global.<element>".

/// Profile tab — avatar + edit form + links + account actions.
struct ProfileEditScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Profile"] }
    var title: XCUIElement { app.staticTexts["EDIT PROFILE"] }

    var avatarButton: XCUIElement { element(app, id: "profile.edit.avatar") }
    var revertPhotoButton: XCUIElement { element(app, id: "profile.edit.revertPhoto") }
    var imageErrorPanel: XCUIElement { element(app, id: "profile.edit.imageError") }

    var nameField: XCUIElement { app.textFields["profile.edit.nameField"] }
    var countryPicker: XCUIElement { element(app, id: "profile.edit.countryPicker") }
    var themePicker: XCUIElement { element(app, id: "profile.edit.themePicker") }
    var saveButton: XCUIElement { app.buttons["profile.edit.save"] }

    var supportLink: XCUIElement { element(app, id: "profile.links.support") }
    var aboutLink: XCUIElement { element(app, id: "profile.links.about") }
    var privacyLink: XCUIElement { element(app, id: "profile.links.privacy") }
    var adminLink: XCUIElement { element(app, id: "profile.links.admin") }

    var signOutButton: XCUIElement { app.buttons["profile.account.signOut"] }
    var deleteAccountButton: XCUIElement { app.buttons["profile.account.delete"] }

    /// Opens the country menu picker and selects the option containing `fragment`.
    func pickCountry(containing fragment: String) {
        countryPicker.tap()
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@ AND identifier != 'profile.edit.countryPicker'", fragment
        )).firstMatch.tap()
    }
}

/// Global leaderboard tab (one screen for web /leaderboard + /leaderboard/[id]).
struct GlobalLeaderboardPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Leaderboard"] }
    var tournamentPicker: XCUIElement { element(app, id: "leaderboard.global.tournamentPicker") }
    var retryButton: XCUIElement { app.buttons["leaderboard.global.retry"] }
    var emptyText: XCUIElement { element(app, id: "leaderboard.global.empty") }
    var errorText: XCUIElement { app.staticTexts["Could not load the leaderboard."] }

    /// "N PLAYERS · CHASING" count, pinned to an exact value.
    func playerCount(equals value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == 'leaderboard.global.playerCount' AND label == %@", value
        )).firstMatch
    }

    func row(userID: String) -> XCUIElement {
        element(app, id: "leaderboard.global.row.\(userID)")
    }

    /// Row user IDs in on-screen (rank) order. Consecutive duplicates collapse — the
    /// identifier can surface on more than one wrapper element per row.
    func rowOrder() -> [String] {
        let prefix = "leaderboard.global.row."
        let elements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex
        var order: [String] = []
        for rowElement in elements {
            let uid = String(rowElement.identifier.dropFirst(prefix.count))
            if order.last != uid { order.append(uid) }
        }
        return order
    }

    /// Opens the tournament menu picker and selects the option containing `fragment`.
    func pickTournament(containing fragment: String) {
        tournamentPicker.tap()
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@ AND identifier != 'leaderboard.global.tournamentPicker'", fragment
        )).firstMatch.tap()
    }
}

/// Support destination (pushed from Profile).
struct SupportPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Support"] }
    var descriptionField: XCUIElement { element(app, id: "profile.support.descriptionField") }
    var submitButton: XCUIElement { app.buttons["profile.support.submit"] }

    func counter(equals value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == 'profile.support.counter' AND label == %@", value
        )).firstMatch
    }
}

/// About destination (pushed from Profile) — static ported copy.
struct AboutPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["About"] }
}

/// Privacy policy sheet (presented from Profile).
struct PrivacyPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Privacy"] }
    var doneButton: XCUIElement { app.buttons["Done"] }
}

/// Admin evaluate destination (pushed from Profile, admin only).
struct AdminPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Admin"] }
    var heroTitle: XCUIElement { app.staticTexts["EVALUATE GAMES."] }
}
