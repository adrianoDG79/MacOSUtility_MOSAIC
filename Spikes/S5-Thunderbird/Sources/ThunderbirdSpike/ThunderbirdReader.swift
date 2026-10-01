import Foundation
import SQLite3

public struct ThunderbirdProfile: Equatable, Sendable {
    public let name: String
    public let path: URL
    public let isDefault: Bool
}

/// `profiles.ini`: `[Profile…]` sections list profiles; in recent versions the
/// `[Install…]` section names the default one.
public enum ProfilesIni {
    public static func profiles(in root: URL) throws -> [ThunderbirdProfile] {
        let text = try String(contentsOf: root.appendingPathComponent("profiles.ini"), encoding: .utf8)
        var sections: [(name: String, values: [String: String])] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                sections.append((String(line.dropFirst().dropLast()), [:]))
                continue
            }
            guard let separator = line.firstIndex(of: "="), !sections.isEmpty else { continue }
            sections[sections.count - 1].values[String(line[..<separator])] = String(line[line.index(after: separator)...])
        }
        let installDefault = sections.first { $0.name.hasPrefix("Install") }?.values["Default"]
        return sections.filter { $0.name.hasPrefix("Profile") }.compactMap { section in
            guard let path = section.values["Path"] else { return nil }
            let url = section.values["IsRelative"] == "0" ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
            let isDefault = installDefault.map { $0 == path } ?? (section.values["Default"] == "1")
            return ThunderbirdProfile(name: section.values["Name"] ?? path, path: url, isDefault: isDefault)
        }
    }
}

public struct MboxSummary: Equatable, Sendable {
    public var total = 0
    public var deleted = 0
    public var messageIDs: [String] = []

    public var live: Int {
        total - deleted
    }
}

/// Thunderbird's mbox files. A message starts at a `From ` line that follows a
/// blank line (or the start of the file); body lines that begin with `From `
/// are written as `>From `. Messages deleted but not yet compacted keep the
/// expunged bit (0x0008) in `X-Mozilla-Status`.
public enum Mbox {
    static let expungedFlag: UInt32 = 0x0008

    public static func summarize(_ url: URL) throws -> MboxSummary {
        let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        var summary = MboxSummary()
        var previousLineBlank = true
        var inHeaders = false
        var deleted = false
        var messageID: String?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.hasSuffix("\r") ? rawLine.dropLast() : rawLine
            defer { previousLineBlank = line.isEmpty }
            if previousLineBlank && line.hasPrefix("From ") {
                summary.total += 1
                inHeaders = true
                deleted = false
                messageID = nil
                continue
            }
            guard inHeaders else { continue }
            if line.isEmpty {
                inHeaders = false
                if deleted {
                    summary.deleted += 1
                } else if let messageID {
                    summary.messageIDs.append(messageID)
                }
                continue
            }
            let lowered = line.lowercased()
            if lowered.hasPrefix("x-mozilla-status:"),
               let value = UInt32(line.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                deleted = value & expungedFlag != 0
            } else if lowered.hasPrefix("message-id:") {
                messageID = line.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return summary
    }

    /// Size and modification date: compaction rewrites the file and changes both.
    public static func state(of url: URL) throws -> [String: Double] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return [
            "size": Double((attributes[.size] as? Int) ?? 0),
            "modified": (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0,
        ]
    }
}

/// Maps a Thunderbird folder URI to its mbox file inside the profile.
public enum FolderURI {
    public static func mboxFile(for uri: String, profile: URL) -> URL? {
        guard let components = URLComponents(string: uri), let scheme = components.scheme, let host = components.host else { return nil }
        let segments = components.path.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard !segments.isEmpty else { return nil }
        var url: URL
        switch scheme {
        case "mailbox": url = profile.appendingPathComponent("Mail").appendingPathComponent(host.removingPercentEncoding ?? host)
        case "imap": url = profile.appendingPathComponent("ImapMail").appendingPathComponent(host)
        default: return nil
        }
        for (index, segment) in segments.enumerated() {
            url = url.appendingPathComponent(index < segments.count - 1 ? segment + ".sbd" : segment)
        }
        return url
    }
}

/// Thunderbird's global search index (`global-messages-db.sqlite`). Only the
/// ordinary tables are read: the full-text table uses Thunderbird's own tokenizer.
public enum Gloda {
    public static func indexedCounts(_ url: URL) throws -> [String: Int] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_close(database) }
        let sql = """
            SELECT f.folderURI, count(m.id) FROM folderLocations f
            LEFT JOIN messages m ON m.folderID = f.id AND m.deleted = 0
            GROUP BY f.id
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileReadCorruptFile) }
        defer { sqlite3_finalize(statement) }
        var counts: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            counts[String(cString: sqlite3_column_text(statement, 0))] = Int(sqlite3_column_int64(statement, 1))
        }
        return counts
    }
}

public struct FolderDiagnosis: Equatable, Sendable {
    public enum Status: String, Sendable {
        case healthy
        case degraded
        case fileUnavailable
    }

    public let folderURI: String
    public let detected: Int?
    public let indexed: Int
    public let status: Status

    public var missing: Int {
        max(0, (detected ?? 0) - indexed)
    }
}

/// "Detected against indexed", as in the §15 example: a folder is degraded
/// when Thunderbird's own index misses more than 5% of its messages.
public enum ThunderbirdDiagnostics {
    public static func diagnose(profile: URL) throws -> [FolderDiagnosis] {
        let indexed = try Gloda.indexedCounts(profile.appendingPathComponent("global-messages-db.sqlite"))
        return indexed.keys.sorted().map { uri in
            let detected = FolderURI.mboxFile(for: uri, profile: profile).flatMap { try? Mbox.summarize($0).live }
            let count = indexed[uri] ?? 0
            let status: FolderDiagnosis.Status
            if let detected {
                status = Double(detected - count) > Double(detected) * 0.05 ? .degraded : .healthy
            } else {
                status = .fileUnavailable
            }
            return FolderDiagnosis(folderURI: uri, detected: detected, indexed: count, status: status)
        }
    }
}
