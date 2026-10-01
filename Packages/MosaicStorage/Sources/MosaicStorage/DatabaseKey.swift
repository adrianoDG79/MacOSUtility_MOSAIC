import Foundation
import MosaicCore
import Security

/// A raw 256-bit SQLCipher key. Raw keys skip PBKDF2, which spike S1 measured
/// at about 100 ms per connection; the key is random, so derivation adds nothing.
public struct DatabaseKey: Sendable {
    public let bytes: Data

    public init(bytes: Data) throws {
        guard bytes.count == 32 else {
            throw MosaicError.invalidFormat("La chiave del database deve essere di 32 byte.")
        }
        self.bytes = bytes
    }

    public static func random() throws -> DatabaseKey {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw MosaicError.internalFailure("Generatore casuale non disponibile (\(status)).")
        }
        return try DatabaseKey(bytes: Data(bytes))
    }

    /// `PRAGMA key` value for a raw key: `x'<64 hex digits>'`.
    var pragmaValue: String {
        "x'" + bytes.map { String(format: "%02x", $0) }.joined() + "'"
    }
}

public protocol DatabaseKeyProvider: Sendable {
    /// The key for `store`. A new key is created only when `createIfMissing` is
    /// true, which the store requests only for a database that does not exist yet.
    func key(for store: StoreKind, createIfMissing: Bool) throws -> DatabaseKey
}

/// One random key per store, kept in the keychain (ADR-006). Keys never leave it.
public struct KeychainDatabaseKeyProvider: DatabaseKeyProvider {
    private let secrets: any SecretsStore

    public init(secrets: any SecretsStore) {
        self.secrets = secrets
    }

    public func key(for store: StoreKind, createIfMissing: Bool) throws -> DatabaseKey {
        let account = "database-key.\(store.rawValue)"
        if let existing = try secrets.data(for: account) {
            return try DatabaseKey(bytes: existing)
        }
        guard createIfMissing else {
            throw MosaicError.notFound(
                "La chiave del database \(store.displayName) non è nel Portachiavi: il database esiste ma non può essere aperto."
            )
        }
        let key = try DatabaseKey.random()
        try secrets.set(key.bytes, for: account)
        return key
    }
}
