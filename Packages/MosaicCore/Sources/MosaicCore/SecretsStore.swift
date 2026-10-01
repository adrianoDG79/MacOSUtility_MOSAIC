import Foundation
import os
import Security

/// Storage for credentials and keys (§60). Values never go to files, logs or
/// plain SQLite columns.
public protocol SecretsStore: Sendable {
    func data(for account: String) throws -> Data?
    func set(_ data: Data, for account: String) throws
    func remove(_ account: String) throws
}

public struct KeychainError: Error, Sendable, CustomStringConvertible {
    public let status: OSStatus

    public var description: String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "codice \(status)"
        return "Portachiavi: \(message)"
    }
}

/// Generic-password items in the user's keychain, scoped to one service name.
///
/// Access is bound to the app's code signature by the keychain itself, which
/// is why Mosaic needs a stable signing identity (R1).
public struct KeychainSecretsStore: SecretsStore {
    public let service: String

    public init(service: String) {
        self.service = service
    }

    public func data(for account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    public func set(_ data: Data, for account: String) throws {
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery(account)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    public func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Secrets kept in memory only, for tests and previews. Values vanish on exit.
public final class InMemorySecretsStore: SecretsStore {
    private let values = OSAllocatedUnfairLock<[String: Data]>(initialState: [:])

    public init() {}

    public func data(for account: String) throws -> Data? {
        values.withLock { $0[account] }
    }

    public func set(_ data: Data, for account: String) throws {
        values.withLock { $0[account] = data }
    }

    public func remove(_ account: String) throws {
        _ = values.withLock { $0.removeValue(forKey: account) }
    }
}
