import Foundation
import SQLite3

/// A Thunderbird profile built from the documented layout: profiles.ini with an
/// [Install…] default, Local Folders with a subfolder (.sbd), an IMAP offline
/// copy, a message deleted but not compacted, and a partial Gloda index.
enum ThunderbirdFixture {
    static let profilePath = "Profiles/x1y2z3ab.default-release"

    static func make(in root: URL) throws -> URL {
        let profile = root.appendingPathComponent(profilePath)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        try """
            [Install4F96D1932A9F858E]
            Default=\(profilePath)
            Locked=1

            [Profile1]
            Name=vecchio
            IsRelative=1
            Path=Profiles/oldprof.default

            [Profile0]
            Name=default-release
            IsRelative=1
            Path=\(profilePath)

            [General]
            StartWithLastProfile=1
            Version=2
            """.write(to: root.appendingPathComponent("profiles.ini"), atomically: true, encoding: .utf8)

        let local = profile.appendingPathComponent("Mail/Local Folders")
        try FileManager.default.createDirectory(at: local.appendingPathComponent("Inbox.sbd"), withIntermediateDirectories: true)
        let imap = profile.appendingPathComponent("ImapMail/imap.example.org")
        try FileManager.default.createDirectory(at: imap, withIntermediateDirectories: true)

        try mbox(inboxMessages(includingDeleted: true)).write(to: local.appendingPathComponent("Inbox"), atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: local.appendingPathComponent("Inbox.msf").path, contents: Data())
        try mbox((1...3).map { message(id: "progetti-\($0)", status: "0001", subject: "Progetto \($0)") })
            .write(to: local.appendingPathComponent("Inbox.sbd/Progetti"), atomically: true, encoding: .utf8)
        try mbox((1...4).map { message(id: "imap-\($0)", status: "0001", subject: "IMAP \($0)") })
            .write(to: imap.appendingPathComponent("INBOX"), atomically: true, encoding: .utf8)

        try makeGloda(at: profile.appendingPathComponent("global-messages-db.sqlite"), folders: [
            (1, "mailbox://nobody@Local%20Folders/Inbox", 4),
            (2, "mailbox://nobody@Local%20Folders/Inbox/Progetti", 1), // Thunderbird indexed only one of three
            (3, "imap://utente@imap.example.org/INBOX", 4),
        ])
        return profile
    }

    static func inboxMessages(includingDeleted: Bool) -> [String] {
        var messages = [message(id: "inbox-1", status: "0001", subject: "Riunione NUSES")]
        if includingDeleted {
            // 0x0009: read (0x0001) and expunged (0x0008), waiting for compaction.
            messages.append(message(id: "inbox-2", status: "0009", subject: "Eliminato ma non compattato"))
        }
        messages.append(message(
            id: "inbox-3", status: "0000", subject: "=?UTF-8?B?UHJldmVudGl2byB0ZXJtb3Z1b3Rv?=",
            body: "Riga normale\n>From the lab, riga con escape\nFrom a line that does not follow a blank line"
        ))
        messages.append(multipartMessage(id: "inbox-4"))
        messages.append(message(id: "inbox-5", status: "0001", subject: "Ultimo"))
        return messages
    }

    static func message(id: String, status: String, subject: String, body: String = "Testo del messaggio.") -> String {
        """
        From - Tue Sep 29 10:00:00 2026
        X-Mozilla-Status: \(status)
        X-Mozilla-Status2: 00000000
        Message-ID: <\(id)@example.org>
        From: Mittente <mittente@example.org>
        To: utente@example.org
        Subject: \(subject)
        Date: Tue, 29 Sep 2026 10:00:00 +0200

        \(body)
        """
    }

    static func multipartMessage(id: String) -> String {
        """
        From - Tue Sep 29 11:00:00 2026
        X-Mozilla-Status: 0001
        Message-ID: <\(id)@example.org>
        From: Fornitore <offerte@example.org>
        Subject: Offerta con allegato
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="confine"

        --confine
        Content-Type: text/plain; charset=utf-8

        Vedi allegato.

        --confine
        Content-Type: application/pdf; name="offerta.pdf"
        Content-Transfer-Encoding: base64
        Content-Disposition: attachment; filename="offerta.pdf"

        JVBERi0xLjQK
        --confine--
        """
    }

    static func mbox(_ messages: [String]) -> String {
        messages.joined(separator: "\n\n") + "\n"
    }

    /// The Gloda tables Mosaic reads, with the columns of Thunderbird's schema.
    private static func makeGloda(at url: URL, folders: [(Int, String, Int)]) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        defer { sqlite3_close(database) }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSDebugDescriptionErrorKey: String(cString: sqlite3_errmsg(database))])
            }
        }
        try execute("""
            CREATE TABLE folderLocations (id INTEGER PRIMARY KEY, folderURI TEXT NOT NULL, dirtyStatus INTEGER NOT NULL,
                                          name TEXT NOT NULL, indexingPriority INTEGER NOT NULL);
            CREATE TABLE messages (id INTEGER PRIMARY KEY, folderID INTEGER, messageKey INTEGER, conversationID INTEGER NOT NULL,
                                   date INTEGER, headerMessageID TEXT, deleted INTEGER NOT NULL DEFAULT 0,
                                   jsonAttributes TEXT, notability INTEGER NOT NULL DEFAULT 0);
            """)
        for (id, uri, indexed) in folders {
            try execute("INSERT INTO folderLocations VALUES (\(id), '\(uri)', 0, 'cartella', 0)")
            for key in 0..<indexed {
                try execute("INSERT INTO messages (folderID, messageKey, conversationID, headerMessageID) VALUES (\(id), \(key), 1, 'm\(id)-\(key)')")
            }
        }
        // A row Thunderbird marked deleted: it must not count as indexed.
        try execute("INSERT INTO messages (folderID, messageKey, conversationID, deleted) VALUES (1, 99, 1, 1)")
    }
}
