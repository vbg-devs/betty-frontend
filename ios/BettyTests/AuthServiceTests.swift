import Foundation
import Testing
@testable import Betty

/// Every write fails like a locked/full Keychain.
private final class FailingSecretStore: SecretStore {
    private var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func read(_ key: String) -> String? { values[key] }
    func write(_ key: String, value: String) throws { throw KeychainError(status: -25299) }
    func delete(_ key: String) { values[key] = nil }
}

/// AuthService state machine with a mocked transport: sign-in, Keychain persistence,
/// session restore, refresh rotation, invalid-grant sign-out, and token caching.
@Suite struct AuthServiceTests {
    private static let signInBody = """
    {
      "kind": "identitytoolkit#VerifyPasswordResponse",
      "localId": "uid-123",
      "email": "a@b.c",
      "displayName": "Ada",
      "idToken": "id-token-1",
      "registered": true,
      "refreshToken": "refresh-1",
      "expiresIn": "3600"
    }
    """

    private static let refreshBody = """
    {
      "access_token": "id-token-2",
      "expires_in": "3600",
      "token_type": "Bearer",
      "refresh_token": "refresh-2",
      "id_token": "id-token-2",
      "user_id": "uid-123",
      "project_id": "406964826017"
    }
    """

    @Test func passwordSignInTransitionsToSignedInAndPersistsRefreshToken() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        transport.handler = { request in
            #expect(request.url!.absoluteString.contains("accounts:signInWithPassword"))
            let body = try #require(request.httpBody)
            let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(payload["email"] as? String == "a@b.c")
            #expect(payload["returnSecureToken"] as? Bool == true)
            return MockTransport.json(Self.signInBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: secrets)

        try await auth.signIn(email: "a@b.c", password: "secret")

        #expect(auth.phase == .signedIn(uid: "uid-123"))
        #expect(auth.currentUID == "uid-123")
        #expect(secrets.read(AuthService.refreshTokenKey) == "refresh-1")
        #expect(auth.providerProfile?.displayName == "Ada")
    }

    @Test func signInFailsLoudlyWhenKeychainWriteFails() async throws {
        let transport = MockTransport()
        transport.handler = { request in MockTransport.json(Self.signInBody, url: request.url) }
        let auth = AuthService(transport: transport, secrets: FailingSecretStore())

        // An unpersisted refresh token would mean a silent sign-out on the next launch.
        await #expect(throws: AuthError.keychainWriteFailed) {
            try await auth.signIn(email: "a@b.c", password: "secret")
        }
        #expect(!auth.isSignedIn)
    }

    @Test func refreshSurvivesAKeychainWriteFailure() async throws {
        let transport = MockTransport()
        let secrets = FailingSecretStore(values: [AuthService.refreshTokenKey: "refresh-1"])
        transport.handler = { request in MockTransport.json(Self.refreshBody, url: request.url) }
        let auth = AuthService(transport: transport, secrets: secrets)

        // The in-memory session is still valid — only persistence of the rotation failed.
        await auth.restoreSession()

        #expect(auth.phase == .signedIn(uid: "uid-123"))
        let token = try await auth.validIDToken()
        #expect(token == "id-token-2")
    }

    @Test func badCredentialsMapToInvalidCredentials() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(
                #"{"error": {"code": 400, "message": "INVALID_LOGIN_CREDENTIALS", "errors": []}}"#,
                status: 400,
                url: request.url
            )
        }
        let auth = AuthService(transport: transport, secrets: InMemorySecretStore())

        await #expect(throws: AuthError.invalidCredentials) {
            try await auth.signIn(email: "a@b.c", password: "wrong")
        }
        #expect(auth.phase == .restoring) // untouched — no state transition on failure
    }

    @Test func restoreWithoutStoredTokenIsSignedOut() async {
        let auth = AuthService(transport: MockTransport(), secrets: InMemorySecretStore())
        await auth.restoreSession()
        #expect(auth.phase == .signedOut)
    }

    @Test func restoreRefreshesAndRotatesTheRefreshToken() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore(values: [AuthService.refreshTokenKey: "refresh-1"])
        transport.handler = { request in
            #expect(request.url!.absoluteString.hasPrefix("https://securetoken.googleapis.com/v1/token"))
            let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            #expect(body == "grant_type=refresh_token&refresh_token=refresh-1")
            return MockTransport.json(Self.refreshBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: secrets)

        await auth.restoreSession()

        #expect(auth.phase == .signedIn(uid: "uid-123"))
        // The rotated token must be persisted (securetoken may rotate it).
        #expect(secrets.read(AuthService.refreshTokenKey) == "refresh-2")
    }

    @Test func expiredRefreshTokenWipesKeychainAndSignsOut() async {
        let transport = MockTransport()
        let secrets = InMemorySecretStore(values: [
            AuthService.refreshTokenKey: "refresh-stale",
            AuthService.uidKey: "uid-123",
        ])
        transport.handler = { request in
            MockTransport.json(
                #"{"error": {"code": 400, "message": "TOKEN_EXPIRED"}}"#,
                status: 400,
                url: request.url
            )
        }
        let auth = AuthService(transport: transport, secrets: secrets)

        await auth.restoreSession()

        #expect(auth.phase == .signedOut)
        #expect(secrets.read(AuthService.refreshTokenKey) == nil)
        #expect(secrets.read(AuthService.uidKey) == nil)
    }

    @Test func validTokenIsCachedUntilNearExpiry() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(Self.signInBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: InMemorySecretStore())
        try await auth.signIn(email: "a@b.c", password: "secret")
        #expect(transport.requests.count == 1)

        // expiresIn 3600 → well above the 5-minute refresh threshold: no network.
        let token = try await auth.validIDToken()
        #expect(token == "id-token-1")
        #expect(transport.requests.count == 1)
    }

    @Test func tokenAfterAuthFailureForcesARefresh() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            if request.url!.absoluteString.contains("signInWithPassword") {
                return MockTransport.json(Self.signInBody, url: request.url)
            }
            return MockTransport.json(Self.refreshBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: InMemorySecretStore())
        try await auth.signIn(email: "a@b.c", password: "secret")

        let fresh = try await auth.tokenAfterAuthFailure()

        #expect(fresh == "id-token-2")
        #expect(transport.requests.count == 2)
    }

    // accounts:signInWithIdp success for Sign in with Apple. Apple never supplies
    // displayName/fullName in the assertion response after the FIRST authorization —
    // the credential's fullName travels as the `fallbackDisplayName`.
    private static let appleIdpSignInBody = """
    {
      "kind": "identitytoolkit#VerifyAssertionResponse",
      "localId": "uid-apple",
      "email": "ada@b.c",
      "idToken": "id-token-apple",
      "refreshToken": "refresh-apple",
      "expiresIn": "3600",
      "providerId": "apple.com",
      "isNewUser": true
    }
    """

    @Test func appleSignInHappyPathPersistsSessionAndSignsIn() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        transport.handler = { request in
            #expect(request.url!.absoluteString.contains("accounts:signInWithIdp"))
            let body = try #require(request.httpBody)
            let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            let postBody = try #require(payload["postBody"] as? String)
            #expect(postBody.contains("id_token=apple-jwt"))
            #expect(postBody.contains("providerId=apple.com"))
            #expect(postBody.contains("nonce=raw-nonce"), "the RAW nonce must go to the IdP, not its SHA-256")
            #expect(payload["returnSecureToken"] as? Bool == true)
            #expect(payload["returnIdpCredential"] as? Bool == true)
            #expect(payload["requestUri"] as? String == FirebaseConfig.requestURI)
            return MockTransport.json(Self.appleIdpSignInBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: secrets)

        try await auth.signInWithApple(identityToken: "apple-jwt", rawNonce: "raw-nonce",
                                       fullName: "Ada Lovelace")

        #expect(auth.phase == .signedIn(uid: "uid-apple"))
        #expect(secrets.read(AuthService.refreshTokenKey) == "refresh-apple")
        #expect(secrets.read(AuthService.uidKey) == "uid-apple")
        // First-authorization name capture: the response has no displayName/fullName,
        // so the credential's name must win through the fallback.
        #expect(auth.providerProfile == AuthService.ProviderProfile(
            email: "ada@b.c", displayName: "Ada Lovelace", photoURL: nil, isNewUser: true))
        // The fresh ID token is cached — no extra securetoken round-trip.
        let token = try await auth.validIDToken()
        #expect(token == "id-token-apple")
        #expect(transport.requests.count == 1)
    }

    // accounts:signInWithIdp answers 200 WITHOUT token fields when the email already
    // belongs to an account with a different provider.
    private static let needConfirmationBody = """
    {
      "kind": "identitytoolkit#VerifyAssertionResponse",
      "needConfirmation": true,
      "email": "a@b.c",
      "providerId": "apple.com",
      "verifiedProvider": ["google.com"]
    }
    """

    @Test func idpNeedConfirmationSurfacesAccountConflictWithoutSigningIn() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        transport.handler = { request in
            #expect(request.url!.absoluteString.contains("accounts:signInWithIdp"))
            return MockTransport.json(Self.needConfirmationBody, url: request.url)
        }
        let auth = AuthService(transport: transport, secrets: secrets)

        await #expect(throws: AuthError.accountExistsWithDifferentProvider) {
            try await auth.signInWithApple(identityToken: "jwt", rawNonce: "nonce")
        }
        #expect(auth.phase == .restoring) // untouched — no state transition on conflict
        #expect(secrets.read(AuthService.refreshTokenKey) == nil)
        #expect(secrets.read(AuthService.uidKey) == nil)
    }

    @Test func signInResponseMissingTokenFieldsIsInvalidResponse() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(
                #"{"kind": "identitytoolkit#VerifyPasswordResponse", "email": "a@b.c"}"#,
                url: request.url
            )
        }
        let auth = AuthService(transport: transport, secrets: InMemorySecretStore())

        await #expect(throws: AuthError.invalidResponse) {
            try await auth.signIn(email: "a@b.c", password: "secret")
        }
        #expect(auth.phase == .restoring)
    }

    @Test func signOutRacingARefreshDoesNotResurrectTheSession() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        transport.handler = { request in MockTransport.json(Self.signInBody, url: request.url) }
        let auth = AuthService(transport: transport, secrets: secrets)
        try await auth.signIn(email: "a@b.c", password: "secret")

        // The refresh response "arrives" only after signOut already wiped the session —
        // its tokens must NOT be re-persisted and the phase must stay signedOut.
        transport.handler = { request in
            auth.signOut()
            return MockTransport.json(Self.refreshBody, url: request.url)
        }

        await #expect(throws: AuthError.notSignedIn) {
            _ = try await auth.tokenAfterAuthFailure()
        }
        #expect(auth.phase == .signedOut)
        #expect(secrets.read(AuthService.refreshTokenKey) == nil)
        #expect(secrets.read(AuthService.uidKey) == nil)
    }

    @Test func signOutClearsEverything() async throws {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        transport.handler = { request in MockTransport.json(Self.signInBody, url: request.url) }
        let auth = AuthService(transport: transport, secrets: secrets)
        try await auth.signIn(email: "a@b.c", password: "secret")

        auth.signOut()

        #expect(auth.phase == .signedOut)
        #expect(secrets.read(AuthService.refreshTokenKey) == nil)
        #expect(auth.providerProfile == nil)
        await #expect(throws: AuthError.notSignedIn) {
            _ = try await auth.validIDToken()
        }
    }
}
