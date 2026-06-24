import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Google sign-in via `ASWebAuthenticationSession` + PKCE (S256) — no Google SDK.
///
/// Requires an iOS OAuth client ID in Info.plist under `GoogleOAuthClientID`
/// (placeholder by default — see ios/README.md). The redirect URI is the reversed
/// client-ID scheme (`com.googleusercontent.apps.<id>:/oauth2redirect`); iOS clients
/// exchange the code without a client secret.
///
/// `signIn()` returns the Google `id_token` to feed into
/// `AuthService.signInWithGoogle(idToken:)`.
final class GoogleOAuthFlow: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private let transport: any HTTPTransport

    /// Test hook: takes precedence over the launch environment and Info.plist,
    /// so unit tests stay deterministic whatever client ID the build ships.
    var clientIDOverride: String?

    init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    func signIn() async throws -> String {
        var configured = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String
        #if DEBUG
        // UI tests override the shipped client ID so the not-configured boundary
        // stays testable regardless of the real Info.plist value.
        if let override = ProcessInfo.processInfo.environment["BETTY_GOOGLE_CLIENT_ID"] {
            configured = override
        }
        if let override = clientIDOverride {
            configured = override
        }
        #endif
        guard let clientID = configured,
              clientID.hasSuffix(".apps.googleusercontent.com"),
              !clientID.hasPrefix("YOUR_")
        else {
            throw AuthError.googleClientIDMissing
        }

        let bareID = String(clientID.dropLast(".apps.googleusercontent.com".count))
        let scheme = "com.googleusercontent.apps.\(bareID)"
        let redirectURI = "\(scheme):/oauth2redirect"

        let verifier = try Self.randomURLSafeString(bytes: 32)
        let challenge = Self.base64URLEncodedSHA256(of: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let callbackURL = try await authenticate(url: components.url!, callbackScheme: scheme)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw AuthError.invalidResponse
        }
        return try await exchangeCode(code, clientID: clientID, redirectURI: redirectURI, verifier: verifier)
    }

    private func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.userCancelled)
                } else {
                    continuation.resume(throwing: AuthError.transportFailure)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            // When start() returns false the completion handler is NEVER called — the
            // continuation (and the caller's busy state) would leak forever.
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: AuthError.transportFailure)
            }
        }
    }

    func exchangeCode(_ code: String, clientID: String, redirectURI: String, verifier: String) async throws -> String {
        struct TokenResponse: Decodable {
            let idToken: String
            enum CodingKeys: String, CodingKey { case idToken = "id_token" }
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "grant_type=authorization_code",
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)",
            "code_verifier=\(verifier)",
            "client_id=\(clientID)",
            "redirect_uri=\(redirectURI)",
        ].joined(separator: "&")
        request.httpBody = Data(form.utf8)

        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return token.idToken
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    /// The anchor must be a window attached to an active scene — a detached
    /// `ASPresentationAnchor()` (fresh `UIWindow`) can fail to present the session.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            + scenes
            .filter { $0.activationState != .foregroundActive }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }

    // MARK: PKCE helpers

    nonisolated static func randomURLSafeString(bytes count: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw AuthError.secureRandomFailed
        }
        return Data(bytes).base64URLEncodedString()
    }

    nonisolated static func base64URLEncodedSHA256(of input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    nonisolated func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
