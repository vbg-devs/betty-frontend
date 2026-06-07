import Foundation
import Observation

/// Firebase Auth over plain REST (Identity Toolkit v1) — no Firebase SDK.
///
/// State machine: `.restoring` (Keychain restore in flight) → `.signedOut` /
/// `.signedIn(uid:)`. The long-lived refresh token (plus the UID) lives in the Keychain;
/// the 1-hour ID token stays in memory and refreshes proactively when < 5 minutes remain.
@Observable
final class AuthService: TokenProviding {
    enum Phase: Equatable {
        case restoring
        case signedOut
        case signedIn(uid: String)
    }

    /// Provider info captured at sign-in for profile completion (Apple only supplies the
    /// full name on FIRST authorization — captured here, pass it to `POST /user`).
    struct ProviderProfile: Equatable {
        var email: String?
        var displayName: String?
        var photoURL: String?
        var isNewUser: Bool
    }

    private(set) var phase: Phase = .restoring
    private(set) var providerProfile: ProviderProfile?

    var currentUID: String? {
        if case .signedIn(let uid) = phase { uid } else { nil }
    }

    var isSignedIn: Bool { currentUID != nil }

    static let refreshTokenKey = "social.betty.firebase.refresh-token"
    static let uidKey = "social.betty.firebase.uid"

    static let defaultIdentityBaseURL = URL(string: "https://identitytoolkit.googleapis.com")!
    static let defaultSecureTokenBaseURL = URL(string: "https://securetoken.googleapis.com")!

    private let transport: any HTTPTransport
    private let secrets: any SecretStore
    private let apiKey: String
    private let identityBaseURL: URL
    private let secureTokenBaseURL: URL
    private let decoder = JSONCoding.makeDecoder()

    private var idToken: String?
    private var idTokenExpiry: Date = .distantPast
    private var refreshTask: Task<String, Error>?

    init(transport: any HTTPTransport = URLSessionTransport(),
         secrets: any SecretStore = KeychainStore(),
         apiKey: String = FirebaseConfig.webAPIKey,
         identityBaseURL: URL = AuthService.defaultIdentityBaseURL,
         secureTokenBaseURL: URL = AuthService.defaultSecureTokenBaseURL) {
        self.transport = transport
        self.secrets = secrets
        self.apiKey = apiKey
        self.identityBaseURL = identityBaseURL
        self.secureTokenBaseURL = secureTokenBaseURL
    }

    // MARK: - Session restore

    /// Restores the session from the Keychain. Invalid-grant errors wipe the Keychain and
    /// land in `.signedOut`; transient (network) failures keep the stored session and land
    /// in `.signedIn` with a lazy refresh on the next `validIDToken()`.
    func restoreSession() async {
        phase = .restoring
        guard secrets.read(Self.refreshTokenKey) != nil else {
            phase = .signedOut
            return
        }
        do {
            _ = try await refreshedIDToken(force: true)
        } catch AuthError.sessionExpired {
            // performRefresh already wiped state via signOut().
        } catch {
            if let uid = secrets.read(Self.uidKey) {
                phase = .signedIn(uid: uid) // offline launch: keep session, refresh lazily
            } else {
                phase = .signedOut
            }
        }
    }

    // MARK: - Email / password

    func signIn(email: String, password: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "returnSecureToken": true]
        let response = try await identityToolkit("accounts:signInWithPassword", jsonBody: body)
        try apply(response)
    }

    func signUp(email: String, password: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "returnSecureToken": true]
        let response = try await identityToolkit("accounts:signUp", jsonBody: body)
        try apply(response)
    }

    // MARK: - Federated (accounts:signInWithIdp)

    /// Sign in with Apple: pass the `ASAuthorization` credential's `identityToken`
    /// (UTF-8 decoded JWT) and the RAW (unhashed) nonce whose SHA-256 went into the
    /// request. `fullName` is only delivered on first authorization.
    func signInWithApple(identityToken: String, rawNonce: String, fullName: String? = nil) async throws {
        let postBody = "id_token=\(identityToken)&providerId=apple.com&nonce=\(rawNonce)"
        try await signInWithIdp(postBody: postBody, fallbackDisplayName: fullName)
    }

    /// Sign in with Google: pass the Google `id_token` from the PKCE code exchange
    /// (see `GoogleOAuthFlow`).
    func signInWithGoogle(idToken: String) async throws {
        let postBody = "id_token=\(idToken)&providerId=google.com"
        try await signInWithIdp(postBody: postBody, fallbackDisplayName: nil)
    }

    private func signInWithIdp(postBody: String, fallbackDisplayName: String?) async throws {
        let body: [String: Any] = [
            "postBody": postBody,
            "requestUri": FirebaseConfig.requestURI,
            "returnSecureToken": true,
            "returnIdpCredential": true,
        ]
        let response = try await identityToolkit("accounts:signInWithIdp", jsonBody: body)
        // Must be checked BEFORE the token fields: a needConfirmation answer carries
        // no localId/idToken/refreshToken (sign-in did not complete).
        if response.needConfirmation == true {
            throw AuthError.accountExistsWithDifferentProvider
        }
        try apply(response, fallbackDisplayName: fallbackDisplayName)
    }

    // MARK: - Sign out

    func signOut() {
        secrets.delete(Self.refreshTokenKey)
        secrets.delete(Self.uidKey)
        idToken = nil
        idTokenExpiry = .distantPast
        refreshTask?.cancel()
        refreshTask = nil
        providerProfile = nil
        phase = .signedOut
    }

    // MARK: - TokenProviding

    func validIDToken() async throws -> String {
        guard isSignedIn else { throw AuthError.notSignedIn }
        if let idToken, idTokenExpiry > Date().addingTimeInterval(5 * 60) {
            return idToken
        }
        return try await refreshedIDToken(force: false)
    }

    func tokenAfterAuthFailure() async throws -> String {
        guard isSignedIn else { throw AuthError.notSignedIn }
        return try await refreshedIDToken(force: true)
    }

    // MARK: - Refresh (securetoken.googleapis.com, deduplicated in-flight)

    private func refreshedIDToken(force: Bool) async throws -> String {
        if !force, let idToken, idTokenExpiry > Date().addingTimeInterval(5 * 60) {
            return idToken
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = secrets.read(Self.refreshTokenKey) else {
            signOut()
            throw AuthError.notSignedIn
        }
        var request = URLRequest(url: URL(string: "\(secureTokenBaseURL.absoluteString)/v1/token?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = Data(form.utf8)

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw AuthError.transportFailure
        }
        // A signOut() that raced this refresh must not resurrect the session (or wipe a
        // successor's): bail before touching the Keychain, phase, or error mapping.
        guard !Task.isCancelled, secrets.read(Self.refreshTokenKey) != nil else {
            throw AuthError.notSignedIn
        }
        guard response.statusCode == 200 else {
            let mapped = Self.mapErrorBody(data)
            if mapped == .sessionExpired || mapped == .userDisabled {
                signOut()
                throw AuthError.sessionExpired
            }
            throw mapped
        }
        guard let refresh = try? decoder.decode(FirebaseRefreshResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        do {
            try secrets.write(Self.refreshTokenKey, value: refresh.refreshToken)
            try secrets.write(Self.uidKey, value: refresh.userId)
        } catch {
            // The in-memory session stays valid and the previously stored refresh token
            // usually still works — don't fail an otherwise-successful refresh.
            // KeychainStore already logged the failing status.
        }
        idToken = refresh.idToken
        idTokenExpiry = Date().addingTimeInterval(TimeInterval(refresh.expiresIn) ?? 3600)
        phase = .signedIn(uid: refresh.userId)
        return refresh.idToken
    }

    // MARK: - Identity Toolkit plumbing

    private func identityToolkit(_ action: String, jsonBody: [String: Any]) async throws -> FirebaseSignInResponse {
        let url = URL(string: "\(identityBaseURL.absoluteString)/v1/\(action)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: jsonBody)

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw AuthError.transportFailure
        }
        guard response.statusCode == 200 else {
            throw Self.mapErrorBody(data)
        }
        guard let signIn = try? decoder.decode(FirebaseSignInResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return signIn
    }

    private func apply(_ response: FirebaseSignInResponse, fallbackDisplayName: String? = nil) throws {
        guard let localId = response.localId,
              let idToken = response.idToken,
              let refreshToken = response.refreshToken
        else {
            throw AuthError.invalidResponse
        }
        do {
            try secrets.write(Self.refreshTokenKey, value: refreshToken)
            try secrets.write(Self.uidKey, value: localId)
        } catch {
            // Fail the sign-in loudly: an unpersisted refresh token would surface later
            // as an unexplained sign-out on the next launch.
            throw AuthError.keychainWriteFailed
        }
        self.idToken = idToken
        idTokenExpiry = Date().addingTimeInterval(response.expiresIn.flatMap(TimeInterval.init) ?? 3600)
        providerProfile = ProviderProfile(
            email: response.email,
            displayName: response.displayName ?? response.fullName ?? fallbackDisplayName,
            photoURL: response.photoUrl,
            isNewUser: response.isNewUser ?? false
        )
        phase = .signedIn(uid: localId)
    }

    private nonisolated static func mapErrorBody(_ data: Data) -> AuthError {
        guard let envelope = try? JSONDecoder().decode(FirebaseErrorEnvelope.self, from: data) else {
            return .invalidResponse
        }
        return AuthError.map(code: envelope.error.message)
    }
}
