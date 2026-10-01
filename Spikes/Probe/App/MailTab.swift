import SQLite3
import SwiftUI

/// Spike S5: Apple Mail store on this macOS version. Reports schema names and
/// counts only: no addresses, subjects, bodies or mailbox names.
struct MailTab: View {
    @State private var report: [String: Any] = [:]
    @State private var status = "Richiede l'accesso completo al disco per Mosaic Probe."
    @State private var busy = false

    var body: some View {
        Form {
            Section("Archivio di Apple Mail") {
                Text(status)
                    .foregroundStyle(.secondary)
                Button("Analizza") {
                    busy = true
                    status = "Analisi in corso…"
                    Task.detached {
                        let result = MailAnalyzer.run()
                        await MainActor.run {
                            report = result
                            status = "Analisi completata."
                            busy = false
                        }
                    }
                }
                .disabled(busy)
            }
            if !report.isEmpty {
                Section("Risultati (solo valori aggregati)") {
                    ForEach(report.keys.sorted().filter { $0 != "schema" }, id: \.self) { key in
                        LabeledContent(key, value: String(describing: report[key]!))
                            .textSelection(.enabled)
                    }
                    if let schema = report["schema"] as? [String: [String]] {
                        Text("Schema: \(schema.count) tabelle")
                        ForEach(schema.keys.sorted(), id: \.self) { table in
                            Text("\(table): \(schema[table]!.joined(separator: ", "))")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    Button("Salva risultati") {
                        let url = ResultStore.save(report, as: "s5-mail")
                        status = url.map { "Salvato in \($0.path)" } ?? "Errore di salvataggio"
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

enum MailAnalyzer {
    static func run() -> [String: Any] {
        var report: [String: Any] = [:]
        let base = Permissions.mailDirectory
        let access = ProbeIO.listDirectory(base)
        report["full_disk_access"] = access.1 == 0
        guard access.1 == 0 else {
            report["error"] = ProbeIO.describeError(access.1)
            return report
        }
        let versions = ((try? FileManager.default.contentsOfDirectory(atPath: base)) ?? [])
            .filter { $0.hasPrefix("V") && Int($0.dropFirst()) != nil }
            .sorted { Int($0.dropFirst())! < Int($1.dropFirst())! }
        report["version_directories"] = versions
        guard let version = versions.last(where: { FileManager.default.fileExists(atPath: "\(base)/\($0)/MailData/Envelope Index") }) else {
            report["envelope_index_found"] = false
            return report
        }
        report["selected_version"] = version
        let root = "\(base)/\(version)"
        let indexPath = "\(root)/MailData/Envelope Index"
        report["envelope_index_bytes"] = (try? FileManager.default.attributesOfItem(atPath: indexPath)[.size] as? Int) ?? -1

        let schemaStart = Date()
        var database: OpaquePointer?
        if sqlite3_open_v2(indexPath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            defer { sqlite3_close(database) }
            let tables = rows(database, "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").map { $0[0] }
            var schema: [String: [String]] = [:]
            for table in tables {
                schema[table] = rows(database, "PRAGMA table_info(\"\(table)\")").map { $0[1] }
            }
            report["schema"] = schema
            if let messageColumns = schema["messages"] {
                report["messages_rows"] = scalar(database, "SELECT count(*) FROM messages")
                if messageColumns.contains("deleted") {
                    report["messages_marked_deleted"] = scalar(database, "SELECT count(*) FROM messages WHERE deleted != 0")
                }
                if messageColumns.contains("mailbox") {
                    let perMailbox = rows(database, "SELECT count(*) FROM messages GROUP BY mailbox ORDER BY 1 DESC").compactMap { Int($0[0]) }
                    report["mailboxes_with_messages"] = perMailbox.count
                    report["messages_per_mailbox_top10"] = Array(perMailbox.prefix(10))
                }
            }
            if schema["mailboxes"] != nil {
                report["mailboxes_rows"] = scalar(database, "SELECT count(*) FROM mailboxes")
            }
        } else {
            report["envelope_open_error"] = String(cString: sqlite3_errmsg(database))
        }
        report["schema_seconds"] = Date().timeIntervalSince(schemaStart)

        // Message files: counts, sizes and a structural check of a sample.
        let walkStart = Date()
        var complete = 0
        var partial = 0
        var bytes: Int64 = 0
        var accounts = 0
        var sample: [String] = []
        if let top = try? FileManager.default.contentsOfDirectory(atPath: root) {
            accounts = top.filter { UUID(uuidString: $0) != nil }.count
        }
        let enumerator = FileManager.default.enumerator(atPath: root)
        while let relative = enumerator?.nextObject() as? String {
            if relative.hasSuffix(".partial.emlx") {
                partial += 1
            } else if relative.hasSuffix(".emlx") {
                complete += 1
                if sample.count < 300 { sample.append(relative) }
            } else {
                continue
            }
            bytes += Int64((enumerator?.fileAttributes?[.size] as? Int) ?? 0)
        }
        report["account_directories"] = accounts
        report["emlx_complete"] = complete
        report["emlx_partial"] = partial
        report["emlx_bytes"] = bytes
        report["walk_seconds"] = Date().timeIntervalSince(walkStart)

        var wellFormed = 0
        for relative in sample {
            guard let handle = FileHandle(forReadingAtPath: "\(root)/\(relative)") else { continue }
            let head = String(decoding: handle.readData(ofLength: 32_768), as: UTF8.self)
            handle.closeFile()
            // .emlx: a first line with the byte count, then an RFC 5322 message.
            let firstLine = head.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let hasLength = Int(firstLine.trimmingCharacters(in: .whitespaces)) != nil
            let lowered = head.lowercased()
            if hasLength && (lowered.contains("\nfrom:") || lowered.contains("\nmessage-id:")) {
                wellFormed += 1
            }
        }
        report["sample_checked"] = sample.count
        report["sample_well_formed"] = wellFormed
        return report
    }

    private static func rows(_ database: OpaquePointer?, _ sql: String) -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append((0..<sqlite3_column_count(statement)).map { column in
                sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
            })
        }
        return result
    }

    private static func scalar(_ database: OpaquePointer?, _ sql: String) -> Int {
        rows(database, sql).first.flatMap { Int($0[0]) } ?? -1
    }
}
