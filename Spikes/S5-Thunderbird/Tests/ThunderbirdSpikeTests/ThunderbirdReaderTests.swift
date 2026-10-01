import Foundation
import Testing
@testable import ThunderbirdSpike

/// Runs `body` on a fresh fixture profile and removes it afterwards.
private func withFixture(_ body: (_ root: URL, _ profile: URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("thunderbird-fixture-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root, try ThunderbirdFixture.make(in: root))
}

struct ThunderbirdReaderTests {
    @Test func findsTheDefaultProfileFromTheInstallSection() throws {
        try withFixture { root, profile in
            let profiles = try ProfilesIni.profiles(in: root)
            #expect(profiles.count == 2)
            guard let preferred = profiles.first(where: \.isDefault) else {
                Issue.record("No default profile")
                return
            }
            #expect(preferred.name == "default-release")
            #expect(preferred.path.standardizedFileURL == profile.standardizedFileURL)
        }
    }

    @Test func countsLiveMessagesAndSkipsDeletedOnes() throws {
        try withFixture { _, profile in
            let inbox = try Mbox.summarize(profile.appendingPathComponent("Mail/Local Folders/Inbox"))
            #expect(inbox.total == 5)
            #expect(inbox.deleted == 1)
            #expect(inbox.live == 4)
            #expect(!inbox.messageIDs.contains("<inbox-2@example.org>"))
            #expect(inbox.messageIDs.contains("<inbox-4@example.org>"))
        }
    }

    @Test func mapsFolderURIsToMboxFiles() throws {
        try withFixture { _, profile in
            let subfolder = FolderURI.mboxFile(for: "mailbox://nobody@Local%20Folders/Inbox/Progetti", profile: profile)
            #expect(subfolder?.path == profile.appendingPathComponent("Mail/Local Folders/Inbox.sbd/Progetti").path)
            let imap = FolderURI.mboxFile(for: "imap://utente@imap.example.org/INBOX", profile: profile)
            #expect(imap?.path == profile.appendingPathComponent("ImapMail/imap.example.org/INBOX").path)
        }
    }

    @Test func reportsAFolderThatThunderbirdIndexedOnlyInPart() throws {
        try withFixture { _, profile in
            let diagnosis = try ThunderbirdDiagnostics.diagnose(profile: profile)
            guard let projects = diagnosis.first(where: { $0.folderURI.hasSuffix("/Progetti") }) else {
                Issue.record("Subfolder missing from the diagnosis")
                return
            }
            #expect(projects.status == .degraded)
            #expect(projects.detected == 3)
            #expect(projects.missing == 2)
            #expect(diagnosis.filter { $0.status == .healthy }.count == 2)
        }
    }

    @Test func noticesCompactionAndRecountsAfterIt() throws {
        try withFixture { _, profile in
            let inbox = profile.appendingPathComponent("Mail/Local Folders/Inbox")
            let before = try Mbox.state(of: inbox)
            // Compaction rewrites the mbox without the deleted message.
            try ThunderbirdFixture.mbox(ThunderbirdFixture.inboxMessages(includingDeleted: false))
                .write(to: inbox, atomically: true, encoding: .utf8)
            #expect(try Mbox.state(of: inbox) != before)
            let after = try Mbox.summarize(inbox)
            #expect(after.deleted == 0)
            #expect(after.live == 4)
        }
    }
}
