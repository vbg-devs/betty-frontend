import Foundation

/// The hermetic Betty backend hosted inside the UI-test runner: an HTTP server (Betty
/// API + Identity Toolkit + securetoken, one port) and a WebSocket broadcast server
/// (second port), both on 127.0.0.1 ephemeral ports. All routes resolve from a single
/// `MockScenario` behind a lock, so mutations through the API are visible to later GETs
/// and tests can inspect/modify state via `withScenario`.
///
/// Token scheme (stateless): ID token `mock-id-token-<uid>`, refresh token
/// `mock-refresh-<uid>`. The seeded-auth fast path hands the app a refresh token via
/// launch environment; the mock securetoken endpoint exchanges it for the ID token.
final class BettyMockBackend: @unchecked Sendable {
    let http = MockHTTPServer()
    let webSocket = MockWebSocketServer()

    private let lock = NSLock()
    private var state: MockScenario

    init(scenario: MockScenario = DefaultScenario.build()) {
        state = scenario
    }

    func start() throws {
        try http.start()
        try webSocket.start()
        registerIdentityRoutes()
        registerAPIRoutes()
    }

    func stop() {
        http.stop()
        webSocket.stop()
    }

    // MARK: - URLs for the app's launch environment

    var httpBase: String { "http://127.0.0.1:\(http.port)" }
    var apiBaseURL: URL { URL(string: "\(httpBase)/api/v1")! }
    var identityBaseURL: URL { URL(string: httpBase)! }
    var secureTokenBaseURL: URL { URL(string: httpBase)! }
    var webSocketURL: URL { URL(string: "ws://127.0.0.1:\(webSocket.port)")! }
    /// R2-public-base equivalent — committed image URLs must start with this.
    var publicAssetBase: String { "\(httpBase)/_public" }

    // MARK: - Tokens

    func idToken(for uid: String) -> String { "mock-id-token-\(uid)" }
    func refreshToken(for uid: String) -> String { "mock-refresh-\(uid)" }

    func uid(fromRefreshToken token: String) -> String? {
        token.hasPrefix("mock-refresh-") ? String(token.dropFirst("mock-refresh-".count)) : nil
    }

    // MARK: - Scenario access

    /// Runs `body` with exclusive access to the scenario (handlers use the same lock).
    func withScenario<T>(_ body: (inout MockScenario) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&state)
    }

    var scenario: MockScenario {
        get { withScenario { $0 } }
        set { withScenario { $0 = newValue } }
    }

    // MARK: - WebSocket push

    /// Broadcasts `{"type": <type>, "message": <message>}` to every connected client.
    /// `message` must be JSONSerialization-compatible (`[String: Any]`, `NSNull`, ...).
    func pushEvent(type: String, message: Any? = nil) {
        let envelope: [String: Any] = ["type": type, "message": message ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket.push(text: text)
    }

    @discardableResult
    func waitForWebSocketClient(timeout: TimeInterval = 10) -> Bool {
        webSocket.waitForClient(timeout: timeout)
    }

    // MARK: - Request assertions

    var recordedRequests: [MockHTTPRequest] { http.recordedRequests }

    /// Handled requests filtered by method and/or path prefix (e.g. "/api/v1/bet").
    func requests(method: String? = nil, pathPrefix: String) -> [MockHTTPRequest] {
        recordedRequests.filter { request in
            (method == nil || request.method == method) && request.path.hasPrefix(pathPrefix)
        }
    }

    // MARK: - Route plumbing shared by MockIdentity / MockAPIRoutes

    /// Registers an authenticated `/api/v1` route. Mirrors the Go middleware exactly:
    /// missing header → `401 {"error":"API token required"}`, unknown/invalid token →
    /// `401 {"error":"Invalid API token"}`. The handler runs INSIDE the scenario lock
    /// with the caller's UID resolved.
    func api(_ method: String, _ pattern: String,
             _ handler: @escaping @Sendable (MockHTTPRequest, [String: String], String, inout MockScenario) -> MockHTTPResponse) {
        http.route(method, "/api/v1\(pattern)") { [weak self] request, params in
            guard let self else { return .empty(500) }
            guard let header = request.headers["authorization"], !header.isEmpty else {
                return .json(["error": "API token required"], status: 401)
            }
            let prefix = "Bearer mock-id-token-"
            guard header.hasPrefix(prefix) else {
                return .json(["error": "Invalid API token"], status: 401)
            }
            let uid = String(header.dropFirst(prefix.count))
            return self.withScenario { scenario in
                guard scenario.user(uid) != nil else {
                    return .json(["error": "Invalid API token"], status: 401)
                }
                return handler(request, params, uid, &scenario)
            }
        }
    }
}
