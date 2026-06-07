import Foundation
import Testing
@testable import Betty

/// Pins the pure logic of the signed-out landing: Firebase error → friendly copy,
/// pre-flight email/password validation, mode-dependent labels, and the landing
/// value props (web `index.vue` parity).
@Suite struct AuthLandingViewTests {
    // MARK: friendlyMessage(for:)

    @Test func mapsKnownAuthErrorsToFriendlyCopy() {
        #expect(AuthLandingView.friendlyMessage(for: .invalidCredentials) == "Wrong email or password.")
        #expect(AuthLandingView.friendlyMessage(for: .emailExists)
            == "An account with this email already exists. Try logging in.")
        #expect(AuthLandingView.friendlyMessage(for: .weakPassword)
            == "Password should be at least 6 characters.")
        #expect(AuthLandingView.friendlyMessage(for: .userDisabled) == "This account has been disabled.")
        #expect(AuthLandingView.friendlyMessage(for: .tooManyAttempts)
            == "Too many attempts — please wait a moment and try again.")
        #expect(AuthLandingView.friendlyMessage(for: .accountExistsWithDifferentProvider)
            == "This email is linked to a different sign-in method.")
        #expect(AuthLandingView.friendlyMessage(for: .googleClientIDMissing)
            == "Google sign-in isn't configured yet (see ios/README.md).")
    }

    @Test func cancelledSignInShowsNoError() {
        #expect(AuthLandingView.friendlyMessage(for: .userCancelled) == nil)
    }

    @Test func unknownErrorsFallBackToGenericCopy() {
        let generic = "Could not sign you in. Please try again."
        #expect(AuthLandingView.friendlyMessage(for: .firebase(code: "SOMETHING_NEW")) == generic)
        #expect(AuthLandingView.friendlyMessage(for: .sessionExpired) == generic)
        #expect(AuthLandingView.friendlyMessage(for: .invalidResponse) == generic)
        #expect(AuthLandingView.friendlyMessage(for: .transportFailure) == generic)
        #expect(AuthLandingView.friendlyMessage(for: .notSignedIn) == generic)
    }

    // MARK: validationMessage(email:password:isSignUp:)

    @Test func validFormPassesInBothModes() {
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "secret1", isSignUp: false) == nil)
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "secret1", isSignUp: true) == nil)
    }

    @Test func emailIsTrimmedBeforeValidation() {
        #expect(AuthLandingView.validationMessage(email: "  a@b.co\n", password: "secret1", isSignUp: false) == nil)
    }

    @Test func malformedEmailsAreRejected() {
        let message = "Enter a valid email address."
        #expect(AuthLandingView.validationMessage(email: "", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "nodomain", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "@b.co", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "a@b", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "a@.co", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "a@b.", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "a b@c.co", password: "secret1", isSignUp: false) == message)
        #expect(AuthLandingView.validationMessage(email: "a@b@c.co", password: "secret1", isSignUp: false) == message)
    }

    @Test func emptyPasswordIsRejectedInBothModes() {
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "", isSignUp: false)
            == "Enter your password.")
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "", isSignUp: true)
            == "Enter your password.")
    }

    @Test func signUpEnforcesSixCharacterMinimumButSignInDoesNot() {
        // Mirrors Firebase WEAK_PASSWORD; sign-in defers to the server (old accounts).
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "12345", isSignUp: true)
            == "Password should be at least 6 characters.")
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "123456", isSignUp: true) == nil)
        #expect(AuthLandingView.validationMessage(email: "a@b.co", password: "12345", isSignUp: false) == nil)
    }

    @Test func emailValidationOrderingEmailFirstThenPassword() {
        #expect(AuthLandingView.validationMessage(email: "bad", password: "", isSignUp: true)
            == "Enter a valid email address.")
    }

    // MARK: mode copy

    @Test func signInModeCopyMatchesWebModal() {
        let copy = AuthLandingView.Copy.mode(isSignUp: false)
        #expect(copy.pitchKicker == "★ WELCOME BACK")
        #expect(copy.pitchTitle == "Sign in")
        #expect(copy.googleTitle == "CONTINUE WITH GOOGLE")
        #expect(copy.emailTitle == "CONTINUE WITH EMAIL")
        #expect(copy.submitTitle == "SIGN IN →")
        #expect(copy.togglePrompt == "Don't have an account?")
        #expect(copy.toggleAction == "Create one")
    }

    @Test func signUpModeCopyMatchesWebModal() {
        let copy = AuthLandingView.Copy.mode(isSignUp: true)
        #expect(copy.pitchKicker == "★ NEW HERE?")
        #expect(copy.pitchTitle == "Create account")
        #expect(copy.googleTitle == "SIGN UP WITH GOOGLE")
        #expect(copy.emailTitle == "SIGN UP WITH EMAIL")
        #expect(copy.submitTitle == "CREATE ACCOUNT →")
        #expect(copy.togglePrompt == "Already have an account?")
        #expect(copy.toggleAction == "Log in")
    }

    // MARK: landing identity

    @Test func valuePropsMatchTheWebLanding() {
        #expect(AuthLandingView.valueProps.map(\.lead)
            == ["Free forever.", "Your house rules.", "Receipts forever."])
        #expect(AuthLandingView.valueProps.map(\.detail) == [
            "No paywalls, no ads, no nonsense.",
            "Each group sets its own scoring.",
            "Leaderboards remember every call.",
        ])
    }
}
