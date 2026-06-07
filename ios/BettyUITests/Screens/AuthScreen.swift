import XCTest

// Auth-area page objects. Extends the shared `AuthLandingScreen` (Screens.swift) with
// the "auth.landing.*" identifiers shipped by Features/Auth, and adds the blocking
// complete-profile gate ("root.completeProfile" + "auth.completeProfile.*").

extension AuthLandingScreen {
    /// Inline error panel under the auth card (sign-in/sign-up failures + local
    /// validation messages).
    var errorPanel: XCUIElement { element(app, id: "auth.landing.error") }
    /// The sign-in ↔ sign-up toggle, mode-independent (labels "Create one" / "Log in").
    var toggleModeButton: XCUIElement { element(app, id: "auth.landing.toggleModeButton") }

    /// Types credentials into the (already open) email form. Does not submit.
    func fillEmailForm(email: String, password: String) {
        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        passwordField.typeText(password)
    }
}

/// Blocking complete-profile cover ("root.completeProfile") shown when GET /user/me
/// 404s after sign-in — name field, menu-style country picker, save.
struct CompleteProfileScreen {
    let app: XCUIApplication

    var root: XCUIElement { element(app, id: "root.completeProfile") }
    var title: XCUIElement { app.staticTexts["COMPLETE YOUR PROFILE"] }
    var nameField: XCUIElement { app.textFields["auth.completeProfile.nameField"] }
    var countryPicker: XCUIElement { element(app, id: "auth.completeProfile.countryPicker") }
    var saveButton: XCUIElement { app.buttons["auth.completeProfile.saveButton"] }
    var errorPanel: XCUIElement { element(app, id: "auth.completeProfile.error") }

    /// A row in the opened country menu (e.g. "🇸🇪 Sweden", "— Not set —"). Menu items
    /// surface as buttons on some OS versions and static texts on others — match any
    /// element type by label so `waitFor` polls a live query either way.
    func countryOption(_ label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }
}
