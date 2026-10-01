import Foundation
import GRDB
import MosaicCore

/// One of Mosaic's SQLite databases, always encrypted with SQLCipher (ADR-006).
///
/// There is deliberately no unencrypted mode: if a key cannot be obtained the
/// store fails to open instead of falling back to plaintext (D7).
public final class MosaicStore: Sendable {
    public let kind: StoreKind
    public let url: URL
    public let writer: DatabasePool

    private init(kind: StoreKind, url: URL, writer: DatabasePool) {
        self.kind = kind
        self.url = url
        self.writer = writer
    }

    /// Opens the store, creating it if needed. When migrations are pending on an
    /// existing database, an encrypted backup is taken first (MOS-DM-001 §6).
    public static func open(
        _ kind: StoreKind,
        in location: StoreLocation,
        keyProvider: any DatabaseKeyProvider,
        migrator: DatabaseMigrator,
        backupRetention: Int = 3
    ) throws -> MosaicStore {
        try location.prepare()
        let url = location.databaseURL(for: kind)
        let existed = FileManager.default.fileExists(atPath: url.path)
        let key = try keyProvider.key(for: kind, createIfMissing: !existed)
        let configuration = makeConfiguration(kind: kind, key: key)

        let pool: DatabasePool
        do {
            pool = try DatabasePool(path: url.path, configuration: configuration)
            // SQLCipher reports a wrong key only on the first read.
            _ = try pool.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master") }
        } catch let error as DatabaseError where error.resultCode == .SQLITE_NOTADB {
            throw MosaicError.invalidFormat(
                "Il database \(kind.displayName) non si apre con la chiave del Portachiavi, oppure è danneggiato."
            )
        }

        if existed, try pool.read({ db in try !migrator.hasCompletedMigrations(db) }) {
            try backup(pool, kind: kind, location: location, configuration: configuration, retention: backupRetention)
        }
        try migrator.migrate(pool)
        try location.restrictPermissions(ofDatabaseAt: url)
        return MosaicStore(kind: kind, url: url, writer: pool)
    }

    public func close() throws {
        try writer.close()
    }

    /// Engine facts shown by the app and checked by tests.
    public func engineInfo() throws -> EngineInfo {
        try writer.read { db in
            EngineInfo(
                sqliteVersion: try String.fetchOne(db, sql: "SELECT sqlite_version()") ?? "?",
                cipherVersion: try String.fetchOne(db, sql: "PRAGMA cipher_version"),
                appliedMigrations: try DatabaseMigrator.appliedIdentifiers(db)
            )
        }
    }

    private static func makeConfiguration(kind: StoreKind, key: DatabaseKey) -> Configuration {
        var configuration = Configuration()
        configuration.label = "mosaic.\(kind.rawValue)"
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA key = \"\(key.pragmaValue)\"")
        }
        return configuration
    }

    @discardableResult
    static func backup(
        _ pool: DatabasePool,
        kind: StoreKind,
        location: StoreLocation,
        configuration: Configuration,
        retention: Int
    ) throws -> URL {
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).dateTimeSeparator(.standard))
            .replacingOccurrences(of: ":", with: "")
        let destinationURL = location.backupDirectory.appending(path: "\(kind.rawValue)-\(stamp)-\(MosaicID.generate()).db")
        let destination = try DatabaseQueue(path: destinationURL.path, configuration: configuration)
        try pool.backup(to: destination)
        try destination.close()
        try location.restrictPermissions(ofDatabaseAt: destinationURL)
        try location.pruneBackups(of: kind, keeping: retention)
        return destinationURL
    }
}

public struct EngineInfo: Sendable, Equatable {
    public let sqliteVersion: String
    /// `nil` would mean the store is not running on SQLCipher.
    public let cipherVersion: String?
    public let appliedMigrations: [String]
}

extension DatabaseMigrator {
    /// Identifiers recorded by GRDB in `grdb_migrations`, in the order they were applied.
    static func appliedIdentifiers(_ db: Database) throws -> [String] {
        guard try db.tableExists("grdb_migrations") else { return [] }
        return try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid")
    }
}
