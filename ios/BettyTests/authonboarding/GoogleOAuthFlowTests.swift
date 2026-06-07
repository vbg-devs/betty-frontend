import Foundation
import Testing
@testable import Betty

/// GoogleOAuthFlow inner logic behind the ASWebAuthenticationSession boundary:
/// PKCE verifier/challenge generation and the authorization-code → id_token exchange
/// (mocked transport — the consent sheet itself is an OS process no test can drive).
@Suite struct GoogleOAuthFlowTests {
    // MARK: - PKCE verifier

    @Test func pkceVerifierIsURLSafeBase64Of32RandomBytes() throws {
        let verifier = try GoogleOAuthFlow.randomURLSafeString(bytes: 32)

        // 32 bytes → ceil(32/3)*4 = 44 chars padded; unpadded base64url = 43.
        #expect(verifier.count == 43)
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(verifier.allSatisfy { allowed.contains($0) },
                "verifier must be base64url — no '+', '/' or '=' may survive")
    }

    @Test func pkceVerifierIsFreshPerInvocation() throws {
        let first = try GoogleOAuthFlow.randomURLSafeString(bytes: 32)
        let second = try GoogleOAuthFlow.randomURLSafeString(bytes: 32)
        #expect(first != second)
    }

    // MARK: - PKCE challenge (S256)

    @Test func pkceChallengeMatchesRFC7636AppendixBVector() {
        // RFC 7636 Appendix B: this verifier must hash to exactly this challenge.
        let challenge = GoogleOAuthFlow.base64URLEncodedSHA256(
            of: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func pkceChallengeIsDeterministicForAGeneratedVerifier() throws {
        let verifier = try GoogleOAuthFlow.randomURLSafeString(bytes: 32)
        #expect(GoogleOAuthFlow.base64URLEncodedSHA256(of: verifier)
            == GoogleOAuthFlow.base64URLEncodedSHA256(of: verifier))
        #expect(GoogleOAuthFlow.base64URLEncodedSHA256(of: verifier).count == 43)
    }

    // MARK: - Code exchange

    private static let clientID = "12345-abc.apps.googleusercontent.com"
    private static let redirectURI = "com.googleusercontent.apps.12345-abc:/oauth2redirect"

    @Test func exchangeCodeSendsPKCEFormAndReturnsIDToken() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            let form = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            #expect(form.contains("grant_type=authorization_code"))
            #expect(form.contains("code=auth-code-1"))
            #expect(form.contains("code_verifier=the-verifier"),
                    "iOS clients exchange with the PKCE verifier, never a client secret")
            #expect(form.contains("client_id=\(Self.clientID)"))
            #expect(form.contains("redirect_uri=\(Self.redirectURI)"))
            #expect(!form.contains("client_secret"))
            return MockTransport.json(
                #"{"access_token": "at", "id_token": "google-id-token-1", "token_type": "Bearer"}"#,
                url: request.url
            )
        }
        let flow = GoogleOAuthFlow(transport: transport)

        let idToken = try await flow.exchangeCode(
            "auth-code-1", clientID: Self.clientID, redirectURI: Self.redirectURI, verifier: "the-verifier")

        #expect(idToken == "google-id-token-1")
        #expect(transport.requests.count == 1)
    }

    @Test func exchangeCodeNon200IsInvalidResponse() async {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(#"{"error": "invalid_grant"}"#, status: 400, url: request.url)
        }
        let flow = GoogleOAuthFlow(transport: transport)

        await #expect(throws: AuthError.invalidResponse) {
            _ = try await flow.exchangeCode(
                "stale-code", clientID: Self.clientID, redirectURI: Self.redirectURI, verifier: "v")
        }
    }

    @Test func exchangeCodeMissingIDTokenIsInvalidResponse() async {
        let transport = MockTransport()
        transport.handler = { request in
            // 200 but no id_token (e.g. the openid scope was dropped).
            MockTransport.json(#"{"access_token": "at", "token_type": "Bearer"}"#, url: request.url)
        }
        let flow = GoogleOAuthFlow(transport: transport)

        await #expect(throws: AuthError.invalidResponse) {
            _ = try await flow.exchangeCode(
                "auth-code-1", clientID: Self.clientID, redirectURI: Self.redirectURI, verifier: "v")
        }
    }

    // MARK: - Client-ID guard

    @Test func signInWithPlaceholderClientIDFailsBeforeAnyNetwork() async {
        // The test host ships the placeholder GoogleOAuthClientID ("YOUR_…") — signIn()
        // must refuse before presenting a session or touching the transport.
        let transport = MockTransport()
        let flow = GoogleOAuthFlow(transport: transport)

        await #expect(throws: AuthError.googleClientIDMissing) {
            _ = try await flow.signIn()
        }
        #expect(transport.requests.isEmpty)
    }
}
