import CryptoKit
import Foundation

/// Nonce helpers for native Sign in with Apple.
///
/// Usage with SwiftUI's `SignInWithAppleButton`:
/// 1. `let nonce = AppleSignInSupport.randomNonce()` (keep it),
/// 2. `request.nonce = AppleSignInSupport.sha256Hex(nonce)`,
///    `request.requestedScopes = [.fullName, .email]`,
/// 3. on success decode `credential.identityToken` as UTF-8 and call
///    `AuthService.signInWithApple(identityToken:rawNonce:fullName:)` with the RAW nonce.
nonisolated enum AppleSignInSupport {
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
