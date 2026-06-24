import XCTest

// Page objects for the main screens.
//
// Accessibility-identifier convention: "<area>.<screen>.<element>", e.g.
// "groupDetail.leaderboard.row.0". App-level containers already ship identifiers
// ("root.splash", "root.authLanding", "root.main", "root.bootFailed",
// "root.completeProfile"). Feature-level identifiers are added by the suite writers
// covering that area (add `.accessibilityIdentifier` to YOUR feature's views only);
// until then page objects fall back to test-pinned copy strings and nav titles.

/// Identifier-or-anything lookup that works for SwiftUI containers (the identifier can
/// land on otherElements, scrollViews, or staticTexts depending on the view tree).
func element(_ app: XCUIApplication, id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
}

/// The 5-tab main chrome (Home, Browse, Leaderboard, Activity, Profile).
struct TabBarScreen {
    let app: XCUIApplication

    var home: XCUIElement { app.tabBars.buttons["Home"] }
    var browse: XCUIElement { app.tabBars.buttons["Browse"] }
    var leaderboard: XCUIElement { app.tabBars.buttons["Leaderboard"] }
    var activity: XCUIElement { app.tabBars.buttons["Activity"] }
    var profile: XCUIElement { app.tabBars.buttons["Profile"] }
}

/// Signed-out landing (hero + Apple/Google/email auth card).
/// KNOWN LIMIT: Apple/Google present OS-process sheets XCUITest cannot drive — test to
/// the boundary (button tap) only; email/password is fully end-to-end against the mock.
struct AuthLandingScreen {
    let app: XCUIApplication

    var root: XCUIElement { element(app, id: "root.authLanding") }
    /// `SignInWithAppleButton` — label is OS-provided ("Continue with Apple" /
    /// "Sign Up with Apple" depending on mode).
    var appleButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Apple'")).firstMatch
    }
    var googleButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'GOOGLE'")).firstMatch
    }
    var showEmailFormButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'EMAIL'")).firstMatch
    }
    var emailField: XCUIElement { app.textFields["Email"] }
    var passwordField: XCUIElement { app.secureTextFields["Password"] }
    var signInSubmitButton: XCUIElement { app.buttons["SIGN IN →"] }
    var createAccountSubmitButton: XCUIElement { app.buttons["CREATE ACCOUNT →"] }
    /// Sign-in ↔ sign-up copy toggle.
    var toggleToSignUp: XCUIElement { app.buttons["Create one"] }
    var toggleToSignIn: XCUIElement { app.buttons["Log in"] }

    /// Full email/password sign-in through the mock identity endpoint.
    func signIn(email: String, password: String) {
        if !emailField.exists { showEmailFormButton.tap() }
        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        passwordField.typeText(password)
        signInSubmitButton.tap()
    }
}

/// Home dashboard (hero, need-action, Running/Ended tabs, group cards).
struct HomeScreen {
    let app: XCUIApplication

    var root: XCUIElement { element(app, id: "root.main") }
    var navigationBar: XCUIElement { app.navigationBars["Home"] }
    /// Toolbar "+" (accessibilityLabel "New group").
    var newGroupButton: XCUIElement { app.buttons["New group"] }
    var newGroupCTA: XCUIElement { app.buttons["+ NEW GROUP"] }
    var runningTab: XCUIElement { app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'RUNNING'")).firstMatch }
    var endedTab: XCUIElement { app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ENDED'")).firstMatch }

    /// Group card title text (cards render `placement.name` verbatim).
    func groupCard(named name: String) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }
}

/// Browse tab (public groups + tournaments).
struct BrowseScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Browse"] }

    func publicGroup(named name: String) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }
}

/// Create-group sheet (router sheet `.createGroup`).
struct CreateGroupScreen {
    let app: XCUIApplication

    var title: XCUIElement { app.staticTexts["START A GROUP"] }
    var successTitle: XCUIElement { app.staticTexts["GROUP CREATED."] }
}

/// Group detail (hero + GROUP / GAMES / LEADERBOARD underline tabs; chat is a push).
/// Suite identifiers: "groupDetail.leaderboard.row.<i>", "groupDetail.games.card.<gameID>", ...
struct GroupDetailScreen {
    let app: XCUIApplication

    var groupTab: XCUIElement { app.buttons["GROUP"] }
    var gamesTab: XCUIElement { app.buttons["GAMES"] }
    var leaderboardTab: XCUIElement { app.buttons["LEADERBOARD"] }

    func leaderboardRow(_ index: Int) -> XCUIElement {
        element(app, id: "groupDetail.leaderboard.row.\(index)")
    }

    func memberName(_ name: String) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }
}

/// Group chat (message board) — pushed from group detail.
struct GroupChatScreen {
    let app: XCUIApplication

    func message(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}

/// Tournaments list / schedule (Browse tab content + detail sheet).
struct TournamentsScreen {
    let app: XCUIApplication

    func tournament(named name: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }
    var viewScheduleButton: XCUIElement { app.buttons["VIEW SCHEDULE →"] }
}

/// Activity tab (live WebSocket event ticker).
struct ActivityScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Activity"] }
    var emptyStateTitle: XCUIElement { app.staticTexts["ALL QUIET."] }
    var clearAllButton: XCUIElement { app.buttons["CLEAR ALL"] }

    func row(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}

/// Profile tab incl. settings rows (Edit Profile, appearance, support, about, sign out).
struct ProfileScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Profile"] }
    var editProfileTitle: XCUIElement { app.staticTexts["EDIT PROFILE"] }

    func row(_ label: String) -> XCUIElement {
        app.staticTexts[label].firstMatch
    }
}
