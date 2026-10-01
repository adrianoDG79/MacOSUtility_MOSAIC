import CryptoKit
import Foundation
import NaturalLanguage
import PDFKit

// Usage:
//   S6Embeddings extract <root> <out.jsonl> [count]   sample documents and extract their text
//   S6Embeddings nlembed <corpus.jsonl> <queries.jsonl> <out.json>
//
// Everything stays in the spike's .data folder, which is not versioned.

struct CorpusDocument: Codable {
    let id: Int
    let language: String
    let chunks: [String]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// MARK: - Extraction

// Work documents only: text and Markdown files on this Mac are mostly source
// code and data, which would not represent what Mosaic users search for.
let supportedExtensions: Set<String> = ["pdf", "docx"]
let excludedNames: Set<String> = ["node_modules", ".git", ".build", "DerivedData", ".venv", "__pycache__", "Library", "Codice"]
/// Documents wanted per language, so cross-language retrieval can be measured.
let languageQuota = ["it": 150, "en": 150]

func candidateFiles(under root: URL) -> [URL] {
    var files: [URL] = []
    let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .isPackageKey]
    let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
    while let url = enumerator?.nextObject() as? URL {
        let values = try? url.resourceValues(forKeys: Set(keys))
        if values?.isDirectory == true {
            if excludedNames.contains(url.lastPathComponent) { enumerator?.skipDescendants() }
            continue
        }
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
        let size = values?.fileSize ?? 0
        if size >= 5_000 && size <= 30_000_000 { files.append(url) }
    }
    return files
}

func extractText(_ url: URL) -> String? {
    switch url.pathExtension.lowercased() {
    case "pdf":
        guard let document = PDFDocument(url: url), !document.isEncrypted else { return nil }
        return (0..<min(document.pageCount, 4)).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
    case "docx":
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        return try? NSAttributedString(url: url, options: options, documentAttributes: nil).string
    default:
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

func normalize(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

func extract(root: URL, output: URL, count: Int) {
    var generator = SystemRandomNumberGenerator()
    let candidates = candidateFiles(under: root).shuffled(using: &generator)
    var seen = Set<String>()
    var documents: [CorpusDocument] = []
    let recognizer = NLLanguageRecognizer()
    var perLanguage: [String: Int] = [:]
    for url in candidates where documents.count < count {
        if languageQuota.allSatisfy({ perLanguage[$0.key, default: 0] >= $0.value }) { break }
        guard let raw = extractText(url) else { continue }
        let text = normalize(raw)
        guard text.count >= 800 else { continue }
        // Several versions of the same document would make "wrong" answers that are
        // really right: keep one document per distinct opening.
        let fingerprint = SHA256.hash(data: Data(text.prefix(1_000).lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
        guard seen.insert(fingerprint).inserted else { continue }
        recognizer.reset()
        recognizer.processString(String(text.prefix(2_000)))
        let language = recognizer.dominantLanguage?.rawValue ?? "und"
        guard let quota = languageQuota[language], perLanguage[language, default: 0] < quota else {
            seen.remove(fingerprint)
            continue
        }
        perLanguage[language, default: 0] += 1
        let chunks = [String(text.prefix(1_000)), String(text.dropFirst(1_000).prefix(1_000))].filter { $0.count >= 200 }
        documents.append(CorpusDocument(id: documents.count, language: language, chunks: chunks))
    }
    let encoder = JSONEncoder()
    let lines = documents.map { String(decoding: try! encoder.encode($0), as: UTF8.self) }.joined(separator: "\n")
    try! lines.write(to: output, atomically: true, encoding: .utf8)
    let languages = Dictionary(grouping: documents, by: \.language).mapValues(\.count)
    print("documenti: \(documents.count) su \(candidates.count) candidati; lingue: \(languages)")
}

// MARK: - NLContextualEmbedding

func meanVector(_ text: String, model: NLContextualEmbedding, language: NLLanguage) throws -> [Double] {
    let result = try model.embeddingResult(for: text, language: language)
    var sum = [Double](repeating: 0, count: model.dimension)
    var count = 0
    result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
        for index in 0..<vector.count { sum[index] += vector[index] }
        count += 1
        return true
    }
    return count == 0 ? sum : sum.map { $0 / Double(count) }
}

func nlEmbed(corpus: URL, queries: URL, output: URL) async throws {
    guard let model = NLContextualEmbedding(script: .latin) else { fail("NLContextualEmbedding non disponibile") }
    if !model.hasAvailableAssets {
        _ = try await model.requestAssets()
    }
    try model.load()
    let decoder = JSONDecoder()
    let documents = try String(contentsOf: corpus, encoding: .utf8).split(separator: "\n").map {
        try decoder.decode(CorpusDocument.self, from: Data($0.utf8))
    }
    let queryRows = try String(contentsOf: queries, encoding: .utf8).split(separator: "\n").map {
        try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
    }
    let start = ContinuousClock.now
    var passageVectors: [[String: Any]] = []
    for document in documents {
        let language = NLLanguage(rawValue: document.language)
        for (index, chunk) in document.chunks.enumerated() {
            passageVectors.append(["doc": document.id, "chunk": index, "vector": try meanVector(chunk, model: model, language: language)])
        }
    }
    let passageSeconds = ContinuousClock.now - start
    var queryVectors: [[String: Any]] = []
    for row in queryRows {
        for key in ["it", "en"] {
            guard let text = row[key] as? String, !text.isEmpty else { continue }
            queryVectors.append(["doc": row["doc"]!, "lang": key,
                                 "vector": try meanVector(text, model: model, language: key == "it" ? .italian : .english)])
        }
    }
    let payload: [String: Any] = [
        "model": "NLContextualEmbedding(latin)", "dimension": model.dimension,
        "max_sequence_length": model.maximumSequenceLength,
        "passage_seconds": Double(passageSeconds.components.seconds) + Double(passageSeconds.components.attoseconds) / 1e18,
        "passages": passageVectors, "queries": queryVectors,
    ]
    try JSONSerialization.data(withJSONObject: payload).write(to: output)
    print("vettori: \(passageVectors.count) passaggi, \(queryVectors.count) query, dimensione \(model.dimension)")
}

// MARK: - Entry point

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "extract" where arguments.count >= 3:
    _ = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
    extract(root: URL(filePath: arguments[1]), output: URL(filePath: arguments[2]), count: Int(arguments.count > 3 ? arguments[3] : "250") ?? 250)
case "nlembed" where arguments.count == 4:
    try await nlEmbed(corpus: URL(filePath: arguments[1]), queries: URL(filePath: arguments[2]), output: URL(filePath: arguments[3]))
default:
    fail("uso: S6Embeddings extract <radice> <out.jsonl> [numero] | nlembed <corpus.jsonl> <queries.jsonl> <out.json>")
}
