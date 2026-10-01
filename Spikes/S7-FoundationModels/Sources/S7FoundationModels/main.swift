import Foundation
import FoundationModels

// Prototype of the SearchIntent of MOS-SRCH-001 §8: the model turns a sentence
// into structured filters; Mosaic would show them as editable chips.

@Generable
enum ItemKind: String {
    case file, pdf, document, spreadsheet, presentation, image, archive, email, attachment, folder, event, any
}

@Generable
enum Goal: String {
    case find, versions, duplicates, organize, delete, explain
}

@Generable
enum DateField: String {
    case none, opened, modified, created, sent, received
}

@Generable
struct SearchIntentDraft {
    @Guide(description: "Kinds of items the user wants. Use 'any' when unclear.")
    var kinds: [ItemKind]
    @Guide(description: "What the user wants to do with the items.")
    var goal: Goal
    @Guide(description: "Names of people mentioned as sender, author or participant, exactly as written.")
    var people: [String]
    @Guide(description: "Subject or topic to search by meaning, in the user's language. Empty if none.")
    var topic: String
    @Guide(description: "Folder or place mentioned, such as Downloads or Desktop. Empty if none.")
    var location: String
    @Guide(description: "Which date the time filter refers to.")
    var dateField: DateField
    @Guide(description: "Start of the time filter as yyyy-MM-dd'T'HH:mm, or empty when there is no lower bound.")
    var start: String
    @Guide(description: "End of the time filter as yyyy-MM-dd'T'HH:mm, or empty when there is no upper bound.")
    var end: String
    @Guide(description: "Minimum size in megabytes, or -1.")
    var minSizeMB: Int
    @Guide(description: "True only if the user asks for items with attachments.")
    var withAttachments: Bool
}

struct Expectation {
    let query: String
    var kinds: Set<ItemKind> = []
    var goal: Goal = .find
    var people: [String] = []
    var location: String = ""
    var start: String? = nil // yyyy-MM-dd
    var end: String? = nil
    var minSizeMB: Int? = nil
    var withAttachments = false
}

// "Now" is Tuesday 29 September 2026, 20:00.
let cases: [Expectation] = [
    Expectation(query: "Where is the PDF I was working on yesterday?", kinds: [.pdf], start: "2026-09-28", end: "2026-09-28"),
    Expectation(query: "Show PDFs larger than 100 MB that I haven't opened in two years", kinds: [.pdf], end: "2024-09-29", minSizeMB: 100),
    Expectation(query: "Find the email Marco sent me around March about the detector tests", kinds: [.email], people: ["Marco"], start: "2026-03-01", end: "2026-03-31"),
    Expectation(query: "Find every version of the NUSES proposal", kinds: [.document], goal: .versions),
    Expectation(query: "Organize Downloads but don't change anything yet", goal: .organize, location: "Downloads"),
    Expectation(query: "Find the email that contained the quote for the NAS", kinds: [.email]),
    Expectation(query: "emails from Maria with attachments last week", kinds: [.email], people: ["Maria"], start: "2026-09-21", end: "2026-09-27", withAttachments: true),
    Expectation(query: "zip files in Downloads bigger than 500 MB", kinds: [.archive], location: "Downloads", minSizeMB: 500),
    Expectation(query: "screenshots from this week", kinds: [.image], start: "2026-09-28", end: "2026-09-29"),
    Expectation(query: "Where did I save the ECSS standard about thermal control?", kinds: [.document]),
    Expectation(query: "presentations I modified in August", kinds: [.presentation], start: "2026-08-01", end: "2026-08-31"),
    Expectation(query: "find duplicate PDFs on the Desktop", kinds: [.pdf], goal: .duplicates, location: "Desktop"),
    Expectation(query: "Trova il PDF su cui lavoravo ieri pomeriggio", kinds: [.pdf], start: "2026-09-28", end: "2026-09-28"),
    Expectation(query: "Mostrami i file più grandi di 2 GB", kinds: [.file], minSizeMB: 2000),
    Expectation(query: "Mail di Francesco del mese scorso sul termovuoto", kinds: [.email], people: ["Francesco"], start: "2026-08-01", end: "2026-08-31"),
    Expectation(query: "Fatture PDF arrivate a settembre", kinds: [.pdf], start: "2026-09-01", end: "2026-09-30"),
    Expectation(query: "Documenti sui requisiti termici di NUSES", kinds: [.document]),
    Expectation(query: "La presentazione della design review di Terzina", kinds: [.presentation]),
    Expectation(query: "Screenshot di questa settimana", kinds: [.image], start: "2026-09-28", end: "2026-09-29"),
    Expectation(query: "Allegati Excel ricevuti da Luca negli ultimi 10 giorni", kinds: [.attachment, .spreadsheet], people: ["Luca"], start: "2026-09-19", end: "2026-09-29"),
    Expectation(query: "La mail di Giulia con il preventivo del termovuoto", kinds: [.email], people: ["Giulia"]),
    Expectation(query: "Cancella i DMG più vecchi di 60 giorni", kinds: [.file], goal: .delete, end: "2026-07-31"),
    Expectation(query: "Tutte le versioni dello schedule di NUSES", kinds: [.spreadsheet, .document], goal: .versions),
    Expectation(query: "Organizza la cartella Download ma mostrami prima il piano", goal: .organize, location: "Download"),
]

func day(_ value: String) -> String { String(value.prefix(10)) }

func within(_ actual: String, _ expected: String?, toleranceDays: Int = 1) -> Bool {
    guard let expected else { return true }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let lhs = formatter.date(from: day(actual)), let rhs = formatter.date(from: expected) else { return false }
    return abs(lhs.timeIntervalSince(rhs)) <= Double(toleranceDays) * 86_400
}

let model = SystemLanguageModel.default
var report: [String: Any] = ["availability": String(describing: model.availability)]
let italian = Locale.Language(identifier: "it")
report["supports_italian"] = model.supportedLanguages.contains { $0.languageCode == italian.languageCode }
if #available(macOS 26.4, *) {
    report["context_size_tokens"] = model.contextSize
}

guard case .available = model.availability else {
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    print("\nFoundation Models non disponibile: la valutazione delle query non è stata eseguita.")
    exit(0)
}

let instructions = """
    You convert a search request typed into a Mac search panel into structured filters.
    Today is Tuesday 29 September 2026 and the time is 20:00. Weeks start on Monday.
    Resolve relative dates ("yesterday", "last month", "a settembre") into concrete dates.
    Requests can be in Italian or English. Keep names and topics in the user's language.
    """

var latencies: [Double] = []
var fieldChecks = 0
var fieldHits = 0
var exactCases = 0
var failures: [String] = []
var rows: [[String: Any]] = []

func progress(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}

/// Fails the query after `seconds` instead of waiting forever.
func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await body() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

let limit = Int(ProcessInfo.processInfo.environment["S7_LIMIT"] ?? "") ?? cases.count
for (index, expectation) in cases.prefix(limit).enumerated() {
    // A fresh session per query, as the search panel would use.
    let start = ContinuousClock.now
    do {
        let response = try await withTimeout(seconds: 120) {
            try await LanguageModelSession(instructions: instructions).respond(to: expectation.query, generating: SearchIntentDraft.self)
        }
        progress("[\(index + 1)/\(limit)] \(ContinuousClock.now - start)")
        let elapsed = ContinuousClock.now - start
        latencies.append(Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
        let intent = response.content

        var checks: [(String, Bool)] = []
        if !expectation.kinds.isEmpty { checks.append(("kinds", !expectation.kinds.isDisjoint(with: intent.kinds))) }
        checks.append(("goal", intent.goal == expectation.goal))
        if !expectation.people.isEmpty {
            checks.append(("people", Set(intent.people.map { $0.lowercased() }) == Set(expectation.people.map { $0.lowercased() })))
        }
        if !expectation.location.isEmpty { checks.append(("location", intent.location.localizedCaseInsensitiveContains(expectation.location))) }
        if expectation.start != nil { checks.append(("start", within(intent.start, expectation.start))) }
        if expectation.end != nil { checks.append(("end", within(intent.end, expectation.end))) }
        if let size = expectation.minSizeMB { checks.append(("size", abs(intent.minSizeMB - size) <= size / 10)) }
        if expectation.withAttachments { checks.append(("attachments", intent.withAttachments)) }

        let hits = checks.filter(\.1).count
        fieldChecks += checks.count
        fieldHits += hits
        if hits == checks.count { exactCases += 1 }
        let missed = checks.filter { !$0.1 }.map(\.0)
        rows.append([
            "query": expectation.query,
            "latency_ms": latencies.last!,
            "missed": missed,
            "got": "kinds=\(intent.kinds.map(\.rawValue)) goal=\(intent.goal.rawValue) people=\(intent.people) topic=\(intent.topic) location=\(intent.location) date=\(intent.dateField.rawValue) \(intent.start)…\(intent.end) minMB=\(intent.minSizeMB) att=\(intent.withAttachments)",
        ])
    } catch {
        failures.append("\(expectation.query): \(error)")
    }
}

let sorted = latencies.sorted()
report["cases"] = limit
report["exact_cases"] = exactCases
report["field_accuracy"] = fieldChecks == 0 ? 0 : Double(fieldHits) / Double(fieldChecks)
report["latency_p50_ms"] = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
report["latency_max_ms"] = sorted.last ?? 0
report["failures"] = failures
report["rows"] = rows
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
print()
