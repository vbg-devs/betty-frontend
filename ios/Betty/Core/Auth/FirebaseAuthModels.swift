import Foundation

enum FirebaseConfig {
    static let webAPIKey = "AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg"
    static let projectID = "betty-f676d"
    /// `requestUri` for accounts:signInWithIdp.
    static let requestURI = "https://betty-f676d.firebaseapp.com"
}

/// Response of accounts:signInWithPassword / accounts:signUp / accounts:signInWithIdp.
/// NOTE: `expiresIn` is a STRING of seconds. The token fields are optional because a
/// `needConfirmation: true` answer (account exists with a different provider) is a 200
/// WITHOUT localId/idToken/refreshToken — sign-in did not complete.
nonisolated struct FirebaseSignInResponse: Decodable, Sendable {
    let localId: String?
    let idToken: String?
    let refreshToken: String?
    let expiresIn: String?
    let email: String?
    let displayName: String?
    let photoUrl: String?
    let fullName: String?
    let providerId: String?
    let isNewUser: Bool?          // only present when true
    let needConfirmation: Bool?   // account exists with a different provider
}

/// Response of `https://securetoken.googleapis.com/v1/token` (snake_case keys).
/// Persist `refreshToken` — it may rotate.
nonisolated struct FirebaseRefreshResponse: Decodable, Sendable {
    let expiresIn: String
    let refreshToken: String
    let idToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case userId = "user_id"
    }
}

/// All Identity Toolkit / securetoken errors are 400 with this envelope.
nonisolated struct FirebaseErrorEnvelope: Decodable, Sendable {
    struct Detail: Decodable, Sendable {
        let code: Int
        let message: String
    }
    let error: Detail
}

/// Auth-layer error with friendly mapping of the Identity Toolkit error codes.
nonisolated enum AuthError: Error, Equatable {
    case notSignedIn
    /// EMAIL_NOT_FOUND / INVALID_PASSWORD / INVALID_LOGIN_CREDENTIALS
    case invalidCredentials
    case emailExists
    case weakPassword
    case userDisabled
    case tooManyAttempts
    /// `needConfirmation: true` — account exists with a different provider for this email.
    case accountExistsWithDifferentProvider
    /// Refresh token rejected (TOKEN_EXPIRED / USER_DISABLED / USER_NOT_FOUND /
    /// INVALID_REFRESH_TOKEN) — force re-login.
    case sessionExpired
    /// INVALID_IDP_RESPONSE — bad nonce / expired identity token.
    case invalidIdentityProviderResponse
    case operationNotAllowed
    /// GoogleOAuthClientID missing from Info.plist (placeholder not replaced).
    case googleClientIDMissing
    case userCancelled
    /// `SecRandomCopyBytes` failed — never fall back to predictable bytes for PKCE.
    case secureRandomFailed
    /// Keychain write failed at sign-in — without the persisted refresh token the
    /// session would silently vanish on the next launch.
    case keychainWriteFailed
    /// Any unmapped Identity Toolkit code (raw message preserved).
    case firebase(code: String)
    case invalidResponse
    case transportFailure

    static func map(code message: String) -> AuthError {
        let head = message.split(separator: ":").first.map(String.init) ?? message
        switch head.trimmingCharacters(in: .whitespaces) {
        case "INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD":
            return .invalidCredentials
        case "EMAIL_EXISTS":
            return .emailExists
        case "WEAK_PASSWORD":
            return .weakPassword
        case "USER_DISABLED":
            return .userDisabled
        case "TOO_MANY_ATTEMPTS_TRY_LATER":
            return .tooManyAttempts
        case "TOKEN_EXPIRED", "USER_NOT_FOUND", "INVALID_REFRESH_TOKEN":
            return .sessionExpired
        case "INVALID_IDP_RESPONSE":
            return .invalidIdentityProviderResponse
        case "OPERATION_NOT_ALLOWED":
            return .operationNotAllowed
        default:
            return .firebase(code: head)
        }
    }
}
