import Foundation
import GRDB
import MosaicCore
import Testing
@testable import MosaicStorage

/// Every test gets its own directory and an in-memory keychain, so nothing
/// touches the real Application Support folder or the login keychain.
private struct Sandbox {
    let location: StoreLocation
    let secrets = InMemorySecretsStore()

    init() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "mosaic-storage-tests-\(MosaicID.generate())")
        location = StoreLocation(directory: directory)
    }

    var keys: KeychainDatabaseKeyProvider {
        KeychainDatabaseKeyProvider(secrets: secrets)
    }

    func openCore(_ migrator: DatabaseMigrator = CoreSchema.migrator) throws -> MosaicStore {
        try MosaicStore.open(.core, in: location, keyProvider: keys, migrator: migrator)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: location.directory)
    }
}

private func header(of url: URL) throws -> Data {
    try FileHandle(forReadingFrom: url).read(upToCount: 16) ?? Data()
}

private let plaintextHeader = Data("SQLite format 3\u{0}".utf8)

struct MosaicStoreTests {
    @Test func createsAnEncryptedStoreWithTheCoreSchema() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }

        let store = try sandbox.openCore()
        let info = try store.engineInfo()
        #expect(info.cipherVersion != nil)
        #expect(info.appliedMigrations == ["v1-foundations"])
        try store.close()
        #expect(try header(of: store.url) != plaintextHeader)
    }

    @Test func reopensWithTheSameKeyWithoutMigratingAgain() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }

        try sandbox.openCore().close()
        let reopened = try sandbox.openCore()
        #expect(try reopened.engineInfo().appliedMigrations == ["v1-foundations"])
        #expect(try sandbox.location.backups(of: .core).isEmpty)
        try reopened.close()
    }

    @Test func refusesToOpenWithoutItsKey() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        try sandbox.openCore().close()

        // A keychain that lost the key must not produce a fresh, unusable key.
        let emptyKeychain = KeychainDatabaseKeyProvider(secrets: InMemorySecretsStore())
        #expect(throws: MosaicError.self) {
            try MosaicStore.open(.core, in: sandbox.location, keyProvider: emptyKeychain, migrator: CoreSchema.migrator)
        }
    }

    @Test func refusesToOpenWithTheWrongKey() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        try sandbox.openCore().close()

        let otherSecrets = InMemorySecretsStore()
        try otherSecrets.set(DatabaseKey.random().bytes, for: "database-key.core")
        let wrongKey = KeychainDatabaseKeyProvider(secrets: otherSecrets)
        #expect(throws: MosaicError.self) {
            try MosaicStore.open(.core, in: sandbox.location, keyProvider: wrongKey, migrator: CoreSchema.migrator)
        }
    }

    @Test func backsUpBeforeRunningPendingMigrations() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let original = try sandbox.openCore()
        try SettingsRepository(store: original).set("prima della migrazione", for: "probe")
        try original.close()

        var extended = CoreSchema.migrator
        extended.registerMigration("v2-test") { db in
            try db.create(table: "probe") { $0.autoIncrementedPrimaryKey("id") }
        }
        let migrated = try sandbox.openCore(extended)
        #expect(try migrated.engineInfo().appliedMigrations == ["v1-foundations", "v2-test"])
        try migrated.close()

        let backups = try sandbox.location.backups(of: .core)
        #expect(backups.count == 1)
        let backup = try #require(backups.first)
        #expect(try header(of: backup) != plaintextHeader)

        // The backup is readable with the same key and holds the pre-migration data.
        let key = try sandbox.keys.key(for: .core, createIfMissing: false)
        var configuration = Configuration()
        configuration.prepareDatabase { db in try db.execute(sql: "PRAGMA key = \"\(key.pragmaValue)\"") }
        let queue = try DatabaseQueue(path: backup.path, configuration: configuration)
        let value = try queue.read { db in try String.fetchOne(db, sql: "SELECT value_json FROM setting WHERE key = 'probe'") }
        #expect(value == "\"prima della migrazione\"")
        #expect(try queue.read { db in try db.tableExists("probe") } == false)
        try queue.close()
    }

    @Test func keepsDatabasesPrivateToTheUser() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let store = try sandbox.openCore()
        defer { try? store.close() }

        func permissions(_ url: URL) throws -> Int {
            try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as! Int
        }
        #expect(try permissions(sandbox.location.directory) == 0o700)
        #expect(try permissions(store.url) == 0o600)
    }

    @Test func storesTypedSettings() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let store = try sandbox.openCore()
        defer { try? store.close() }
        let settings = SettingsRepository(store: store)

        #expect(try settings.value(Int.self, for: "retention.days") == nil)
        try settings.set(30, for: "retention.days")
        try settings.set(90, for: "retention.days")
        #expect(try settings.value(Int.self, for: "retention.days") == 90)
    }

    @Test func registersThisMacOnceAndKeepsItsIdentity() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let info = DeviceInfo(name: "Mac di prova", model: "MacBookPro18,3", osVersion: "26.6.2")

        let first = try sandbox.openCore()
        let device = try DeviceRegistry.currentDevice(in: first, info: info)
        try first.close()

        let second = try sandbox.openCore()
        let again = try DeviceRegistry.currentDevice(in: second, info: DeviceInfo(name: "Altro nome", model: "x", osVersion: "y"))
        try second.close()

        #expect(again == device)
        #expect(device.id.version == 7)
    }

    @Test func storesIdentifiersAsSixteenByteBlobs() throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let store = try sandbox.openCore()
        defer { try? store.close() }

        let id = MosaicID.generate()
        let length = try store.writer.read { db in try Int.fetchOne(db, sql: "SELECT length(?)", arguments: [id]) }
        let roundTrip = try store.writer.read { db in try MosaicID.fetchOne(db, sql: "SELECT ?", arguments: [id]) }
        #expect(length == 16)
        #expect(roundTrip == id)
    }
}
