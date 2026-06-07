import XCTest

// Live-area page objects: the global toast/confirm overlay (LiveToastHost — rendered
// at the top of RootView and re-hosted on every router sheet) and the live-score
// surfaces the WebSocket suite asserts on.

/// Toast / confirm cards. Identifiers shipped by the Live suite:
/// `live.toast.host`, `live.toast.card`, `live.toast.dismiss`, `live.toast.cancel`,
/// `live.toast.confirm`.
struct LiveToastScreen {
    let app: XCUIApplication

    var card: XCUIElement { element(app, id: "live.toast.card") }
    var dismissButton: XCUIElement { app.buttons["live.toast.dismiss"] }
    var cancelButton: XCUIElement { app.buttons["live.toast.cancel"] }
    var confirmButton: XCUIElement { app.buttons["live.toast.confirm"] }

    /// Kicker line — "NICE" (success), "OOPS" (error/critical), "HEADS UP"
    /// (warning/confirm), "BETTY SAYS" (info); rendered as "★ <KICKER>".
    func kicker(_ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "★ \(text)")).firstMatch
    }

    func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}

/// Group GAMES tab scoreboard: team names render uppercased; each score is its own
/// single-digit static text, so freshly pushed scores are matchable exactly.
struct LiveScoreboardScreen {
    let app: XCUIApplication

    func team(_ name: String) -> XCUIElement {
        app.staticTexts[name.uppercased()].firstMatch
    }

    func scoreDigit(_ value: Int) -> XCUIElement {
        app.staticTexts["\(value)"].firstMatch
    }
}
