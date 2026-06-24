import Foundation
import os
import Security

/// Minimal secret persistence — implemented by `KeychainStore` (app) and
/// `InMemorySecretStore` (tests/previews).
protocol SecretStore {
    func read(_ key: String) -> String?
    func write(_ key: String, value: String) throws
    func delete(_ key: String)
}

/// A Keychain operation failed with the carried `SecItem*` status.
nonisolated struct KeychainError: Error {
    let status: OSStatus
}

/// Small Keychain wrapper (kSecClassGenericPassword, service `social.betty.app`,
/// `kSecAttrAccessibleAfterFirstUnlock` so token refresh works on background launches).
final class KeychainStore: SecretStore {
    private static let logger = Logger(subsystem: "social.betty.app", category: "Keychain")

    private let service: String

    init(service: String = "social.betty.app") {
        self.service = service
    }

    func read(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Throws `KeychainError` when the item can neither be updated nor added — a
    /// swallowed failure here surfaces much later as an unexplained sign-out.
    func write(_ key: String, value: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            Self.logger.error("Keychain write failed for \(key, privacy: .public): status \(status)")
            throw KeychainError(status: status)
        }
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

/// Non-persistent store for unit tests and previews.
final class InMemorySecretStore: SecretStore {
    private(set) var values: [String: String] = [:]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func read(_ key: String) -> String? { values[key] }
    func write(_ key: String, value: String) { values[key] = value }
    func delete(_ key: String) { values[key] = nil }
}
