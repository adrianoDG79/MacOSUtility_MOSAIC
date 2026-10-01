import Foundation
import MosaicCore

/// The four databases, split by lifecycle (MOS-DM-001 §2).
public enum StoreKind: String, Sendable, CaseIterable {
    case core
    case index
    case activity
    case telemetry

    public var fileName: String {
        "\(rawValue).db"
    }

    public var displayName: String {
        switch self {
        case .core: "configurazione"
        case .index: "indice"
        case .activity: "attività"
        case .telemetry: "telemetria"
        }
    }
}

/// Directory holding Mosaic's databases and their pre-migration backups.
/// Only the current user can read it: the directory is 0700 and files are 0600.
public struct StoreLocation: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/Mosaic`.
    public static func applicationSupport() throws -> StoreLocation {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return StoreLocation(directory: base.appending(path: "Mosaic", directoryHint: .isDirectory))
    }

    public var backupDirectory: URL {
        directory.appending(path: "Backups", directoryHint: .isDirectory)
    }

    public func databaseURL(for kind: StoreKind) -> URL {
        directory.appending(path: kind.fileName)
    }

    func prepare() throws {
        for url in [directory, backupDirectory] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
    }

    /// Applies 0600 to a database and its WAL companions, when present.
    func restrictPermissions(ofDatabaseAt url: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
    }

    func backups(of kind: StoreKind) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("\(kind.rawValue)-") && $0.pathExtension == "db" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func pruneBackups(of kind: StoreKind, keeping retained: Int) throws {
        for url in try backups(of: kind).dropLast(retained) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
