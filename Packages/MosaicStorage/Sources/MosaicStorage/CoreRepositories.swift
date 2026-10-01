import Foundation
import GRDB
import MosaicCore
import SystemConfiguration

extension MosaicID: @retroactive DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        data.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> MosaicID? {
        Data.fromDatabaseValue(dbValue).flatMap(MosaicID.init(data:))
    }
}

extension Date {
    /// Mosaic stores times as UTC milliseconds since the epoch (MOS-DM-001 §1).
    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }

    init(millisecondsSince1970 milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }
}

/// Typed settings stored as JSON in `core.db`.
public struct SettingsRepository: Sendable {
    private let writer: DatabasePool

    public init(store: MosaicStore) {
        writer = store.writer
    }

    public func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
        let json = try writer.read { db in
            try String.fetchOne(db, sql: "SELECT value_json FROM setting WHERE key = ?", arguments: [key])
        }
        return try json.map { try JSONDecoder().decode(Value.self, from: Data($0.utf8)) }
    }

    public func set<Value: Encodable>(_ value: Value, for key: String, at date: Date = Date()) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = String(decoding: try encoder.encode(value), as: UTF8.self)
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO setting(key, value_json, updated_at) VALUES (?, ?, ?)
                    ON CONFLICT(key) DO UPDATE SET value_json = excluded.value_json, updated_at = excluded.updated_at
                    """,
                arguments: [key, json, date.millisecondsSince1970]
            )
        }
    }
}

public struct DeviceRecord: Sendable, Equatable {
    public let id: MosaicID
    public let name: String
    public let model: String
    public let osVersion: String
    public let firstSeenAt: Date
}

/// Facts about this Mac recorded once, at first launch.
public struct DeviceInfo: Sendable {
    public let name: String
    public let model: String
    public let osVersion: String

    public init(name: String, model: String, osVersion: String) {
        self.name = name
        self.model = model
        self.osVersion = osVersion
    }

    public static var current: DeviceInfo {
        DeviceInfo(
            name: SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "Mac",
            model: hardwareModel() ?? "Mac",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    private static func hardwareModel() -> String? {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}

/// Identity of this Mac inside Mosaic's data (`device_id`, §57).
public enum DeviceRegistry {
    static let currentDeviceKey = "device.current_id"

    /// This Mac's record, created on first launch and stable afterwards.
    public static func currentDevice(in store: MosaicStore, info: DeviceInfo = .current, now: Date = Date()) throws -> DeviceRecord {
        let settings = SettingsRepository(store: store)
        if let id = try settings.value(MosaicID.self, for: currentDeviceKey),
           let record = try fetch(id, in: store) {
            return record
        }
        // Stored with millisecond precision, so the returned record matches later reads.
        let firstSeen = Date(millisecondsSince1970: now.millisecondsSince1970)
        let record = DeviceRecord(id: .generate(at: now), name: info.name, model: info.model, osVersion: info.osVersion, firstSeenAt: firstSeen)
        try store.writer.write { db in
            try db.execute(
                sql: "INSERT INTO device(id, name, model, os_version, first_seen_at) VALUES (?, ?, ?, ?, ?)",
                arguments: [record.id, record.name, record.model, record.osVersion, record.firstSeenAt.millisecondsSince1970]
            )
        }
        try settings.set(record.id, for: currentDeviceKey, at: now)
        return record
    }

    private static func fetch(_ id: MosaicID, in store: MosaicStore) throws -> DeviceRecord? {
        try store.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM device WHERE id = ?", arguments: [id]).map { row in
                DeviceRecord(
                    id: row["id"],
                    name: row["name"],
                    model: row["model"],
                    osVersion: row["os_version"],
                    firstSeenAt: Date(millisecondsSince1970: row["first_seen_at"])
                )
            }
        }
    }
}
