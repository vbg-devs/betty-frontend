import Foundation

/// DEBUG-only launch-environment overrides so the BettyUITests runner can point every
/// network edge (API, Identity Toolkit, securetoken, WebSocket) at its in-process
/// loopback mock backend. In release builds `read()` returns the empty value — the
/// production endpoints always win.
///
/// Keys:
/// - `BETTY_API_BASE_URL`          — replaces `https://api.betty.social/api/v1`
/// - `BETTY_IDENTITY_BASE_URL`     — replaces `https://identitytoolkit.googleapis.com`
/// - `BETTY_SECURETOKEN_BASE_URL`  — replaces `https://securetoken.googleapis.com`
/// - `BETTY_WS_URL`                — replaces `wss://api.betty.social/ws`
/// - `BETTY_UITEST=1`              — wipe Keychain session + UserDefaults at launch
///                                   (deterministic state), then seed the session below
/// - `BETTY_SEED_REFRESH_TOKEN` / `BETTY_SEED_UID` — pre-authenticated fast path: a mock
///                                   refresh token the mock securetoken endpoint accepts
/// - `BETTY_DISABLE_ANIMATIONS=1`  — `UIView.setAnimationsEnabled(false)`
struct LaunchOverrides {
    var apiBaseURL: URL?
    var identityBaseURL: URL?
    var secureTokenBaseURL: URL?
    var webSocketURL: URL?
    var isUITest = false
    var disableAnimations = false
    var seededRefreshToken: String?
    var seededUID: String?

    static func read(environment: [String: String] = ProcessInfo.processInfo.environment) -> LaunchOverrides {
        var overrides = LaunchOverrides()
        #if DEBUG
        overrides.apiBaseURL = environment["BETTY_API_BASE_URL"].flatMap(URL.init(string:))
        overrides.identityBaseURL = environment["BETTY_IDENTITY_BASE_URL"].flatMap(URL.init(string:))
        overrides.secureTokenBaseURL = environment["BETTY_SECURETOKEN_BASE_URL"].flatMap(URL.init(string:))
        overrides.webSocketURL = environment["BETTY_WS_URL"].flatMap(URL.init(string:))
        overrides.isUITest = environment["BETTY_UITEST"] == "1"
        overrides.disableAnimations = environment["BETTY_DISABLE_ANIMATIONS"] == "1"
        overrides.seededRefreshToken = environment["BETTY_SEED_REFRESH_TOKEN"]
        overrides.seededUID = environment["BETTY_SEED_UID"]
        #endif
        return overrides
    }
}
