import Foundation

/// Fixture constants + scenario helpers for the auth e2e suite.
enum AuthFixtures {
    /// Email no DefaultScenario user owns — sign-up creates a fresh Firebase account
    /// (mock uid "uid-signup-<n>") with `hasProfile=false` → onboarding gate.
    static let freshSignupEmail = "newbie@betty.test"
    static let freshSignupPassword = "fresh-secret-1"
    static let freshSignupName = "Newbie Tester"

    /// A refresh token whose uid exists in no scenario — securetoken answers
    /// INVALID_REFRESH_TOKEN (force re-login).
    static let ghostRefreshToken = "mock-refresh-uid-ghost"
    static let ghostUID = "uid-ghost"
}

extension MockScenario {
    /// Drops `uid`'s profile row so GET /user/me 404s — the complete-profile gate.
    mutating func markProfileIncomplete(_ uid: String) {
        updateUser(uid) { $0.hasProfile = false }
    }
}

extension BettyMockBackend {
    /// Re-registers the stock `GET /tournaments` handler (LAST registration wins) —
    /// recovers the boot fan-out after a test forced it to fail.
    func authRestoreTournamentsRoute() {
        api("GET", "/tournaments") { _, _, _, scenario in
            guard !scenario.tournaments.isEmpty else { return .empty(404) }
            return .json(scenario.tournaments.map { MockWire.tournament($0, details: false) })
        }
    }
}
