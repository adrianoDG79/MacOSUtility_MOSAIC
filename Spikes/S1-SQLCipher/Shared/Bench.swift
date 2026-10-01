// Spike S1: costo di SQLCipher su un carico simile all'indice di Mosaic.
//
// Lo stesso codice gira in due eseguibili: S1Plain (GRDB con l'SQLite di sistema)
// e S1Cipher (GRDB con SQLCipher, compilato con MOSAIC_SQLCIPHER). Il corpus è
// sintetico e riproducibile: nessun dato dell'utente entra nel benchmark.

import Foundation
import GRDB

enum BenchMode: String, CaseIterable, Sendable {
    /// GRDB con l'SQLite di sistema.
    case system
    /// GRDB con SQLCipher, database non cifrato: isola il costo della cifratura.
    case cipherNoKey
    /// GRDB con SQLCipher e chiave grezza da 256 bit, senza derivazione (scelta prevista da ADR-006).
    case cipherRawKey
    /// GRDB con SQLCipher e passphrase derivata con PBKDF2: interessa solo il tempo di apertura.
    case cipherPassphrase

    var isEncrypted: Bool { self == .cipherRawKey || self == .cipherPassphrase }
}

struct BenchOptions {
    var mode: BenchMode
    var chunks = 100_000
    var wordsPerChunk = 160
    var files = 300_000
    var queriesPerKind = 200
    var output: URL?

    static func parse(_ arguments: [String], defaultMode: BenchMode) throws -> BenchOptions {
        var options = BenchOptions(mode: defaultMode)
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            guard let value = iterator.next() else { throw BenchError.usage("manca il valore di \(argument)") }
            switch argument {
            case "--mode":
                guard let mode = BenchMode(rawValue: value) else { throw BenchError.usage("modalità sconosciuta: \(value)") }
                options.mode = mode
            case "--chunks": options.chunks = try Self.integer(value, argument)
            case "--files": options.files = try Self.integer(value, argument)
            case "--queries": options.queriesPerKind = try Self.integer(value, argument)
            case "--out": options.output = URL(filePath: value)
            default: throw BenchError.usage("argomento sconosciuto: \(argument)")
            }
        }
        return options
    }

    private static func integer(_ value: String, _ name: String) throws -> Int {
        guard let number = Int(value), number > 0 else { throw BenchError.usage("\(name) richiede un intero positivo") }
        return number
    }
}

enum BenchError: Error, CustomStringConvertible {
    case usage(String)
    case unsupported(String)
    case check(String)

    var description: String {
        switch self {
        case .usage(let message), .unsupported(let message), .check(let message): message
        }
    }
}

// MARK: - Corpus sintetico

/// Generatore deterministico, così ogni esecuzione inserisce lo stesso corpus.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Vocabolario pseudo-bilingue con frequenze di tipo Zipf. Include parole accentate
/// per esercitare `remove_diacritics`. L'indice nell'array coincide con il rango.
struct Corpus {
    let words: [String]
    private let cumulative: [Double]

    init(size: Int, seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        let syllables = ["ta", "ri", "co", "me", "ne", "la", "ter", "mi", "ca", "sa", "pro", "tec", "ra", "zio",
                         "men", "to", "gra", "vi", "spa", "zi", "tu", "ro", "le", "na", "di", "ve", "que", "st",
                         "ar", "en", "ing", "tion", "ser", "ver", "da", "sen", "sor", "mo", "du", "lo", "fe", "pi",
                         "ano", "cryo", "flu", "ssi", "bo", "ga", "ne", "tri", "ex", "ul"]
        let accents = ["à", "è", "é", "ì", "ò", "ù"]
        var words = ["il", "la", "di", "che", "e", "the", "of", "and", "to", "in", "per", "con", "un", "una", "is", "for"]
        var seen = Set(words)
        while words.count < size {
            let length = Int.random(in: 2...4, using: &rng)
            var word = (0..<length).map { _ in syllables.randomElement(using: &rng)! }.joined()
            if Int.random(in: 0..<10, using: &rng) == 0 { word += accents.randomElement(using: &rng)! }
            if seen.insert(word).inserted { words.append(word) }
        }
        var total = 0.0
        var cumulative: [Double] = []
        cumulative.reserveCapacity(size)
        for rank in 1...size {
            total += 1.0 / pow(Double(rank), 1.07)
            cumulative.append(total)
        }
        self.words = words
        self.cumulative = cumulative.map { $0 / total }
    }

    func word(_ rng: inout SplitMix64) -> String {
        let target = rng.unit()
        var low = 0
        var high = cumulative.count - 1
        while low < high {
            let middle = (low + high) / 2
            if cumulative[middle] < target { low = middle + 1 } else { high = middle }
        }
        return words[low]
    }

    func text(words count: Int, _ rng: inout SplitMix64) -> String {
        (0..<count).map { _ in word(&rng) }.joined(separator: " ")
    }

    func fileName(_ rng: inout SplitMix64) -> String {
        let extensions = ["pdf", "docx", "xlsx", "txt", "md", "png", "zip"]
        let stem = [word(&rng), word(&rng), word(&rng)].joined(separator: "_")
        return "\(stem.capitalized)_v\(Int.random(in: 1...9, using: &rng)).\(extensions.randomElement(using: &rng)!)"
    }
}

// MARK: - Misure

let clock = ContinuousClock()

func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
}

func timed<T>(_ body: () throws -> T) rethrows -> (T, Double) {
    var result: T?
    let duration = try clock.measure { result = try body() }
    return (result!, milliseconds(duration))
}

func latencySummary(_ samples: [Double]) -> [String: Double] {
    guard !samples.isEmpty else { return [:] }
    let sorted = samples.sorted()
    func percentile(_ p: Double) -> Double { sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))] }
    return [
        "p50_ms": percentile(0.50),
        "p95_ms": percentile(0.95),
        "p99_ms": percentile(0.99),
        "max_ms": sorted.last!,
        "mean_ms": samples.reduce(0, +) / Double(samples.count),
    ]
}

func peakResidentBytes() -> Int {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Int(usage.ru_maxrss) // su macOS ru_maxrss è in byte
}

func fileSize(_ url: URL) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
}

// MARK: - Chiave

/// Chiave fissa del benchmark: protegge solo dati sintetici, mai dati dell'utente.
let benchmarkRawKeyHex = String(repeating: "5a", count: 32)

func applyKey(_ db: Database, mode: BenchMode) throws {
    #if MOSAIC_SQLCIPHER
    switch mode {
    case .cipherRawKey:
        try db.execute(sql: "PRAGMA key = \"x'\(benchmarkRawKeyHex)'\"")
    case .cipherPassphrase:
        try db.usePassphrase("mosaic-s1-benchmark-passphrase")
    case .system, .cipherNoKey:
        break
    }
    #else
    if mode != .system { throw BenchError.unsupported("questo eseguibile usa l'SQLite di sistema: solo --mode system") }
    #endif
}

func configuration(for mode: BenchMode) -> Configuration {
    var configuration = Configuration()
    configuration.prepareDatabase { db in try applyKey(db, mode: mode) }
    return configuration
}

// MARK: - Benchmark

func runBenchmark(_ options: BenchOptions) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "mosaic-s1-\(options.mode.rawValue)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "bench.sqlite")

    var report: [String: Any] = [
        "mode": options.mode.rawValue,
        "chunks": options.chunks,
        "words_per_chunk": options.wordsPerChunk,
        "files": options.files,
        "queries_per_kind": options.queriesPerKind,
    ]

    let (pool, openMilliseconds) = try timed { try DatabasePool(path: databaseURL.path, configuration: configuration(for: options.mode)) }
    report["open_ms"] = openMilliseconds
    report["engine"] = try pool.read(engineInfo)

    try pool.write { db in
        try db.execute(sql: """
            CREATE TABLE chunk(id INTEGER PRIMARY KEY, owner INTEGER NOT NULL, seq INTEGER NOT NULL, text TEXT NOT NULL);
            CREATE VIRTUAL TABLE chunk_fts USING fts5(
                text, content='chunk', content_rowid='id',
                tokenize='unicode61 remove_diacritics 2', prefix='2 3');
            CREATE TABLE file(id INTEGER PRIMARY KEY, path TEXT NOT NULL, name TEXT NOT NULL,
                              size INTEGER NOT NULL, mtime INTEGER NOT NULL);
            CREATE VIRTUAL TABLE name_fts USING fts5(name, content='file', content_rowid='id', tokenize='trigram');
            """)
    }

    let corpus = Corpus(size: 40_000, seed: 7)
    var rng = SplitMix64(seed: 42)
    var sampleTexts: [String] = []
    var sampleNames: [String] = []

    // Inserimento dei blocchi di testo: si misura solo la scrittura, non la generazione.
    let batchSize = 5_000
    var chunkInsertMilliseconds = 0.0
    var nextID = 1
    while nextID <= options.chunks {
        let lastID = min(nextID + batchSize - 1, options.chunks)
        let batch = (nextID...lastID).map { id in (id, corpus.text(words: options.wordsPerChunk, &rng)) }
        for (id, text) in batch where id % 500 == 0 { sampleTexts.append(text) }
        let (_, elapsed) = try timed {
            try pool.write { db in
                let insertChunk = try db.cachedStatement(sql: "INSERT INTO chunk(id, owner, seq, text) VALUES (?, ?, ?, ?)")
                let insertIndex = try db.cachedStatement(sql: "INSERT INTO chunk_fts(rowid, text) VALUES (?, ?)")
                for (id, text) in batch {
                    try insertChunk.execute(arguments: [id, id / 20, id % 20, text])
                    try insertIndex.execute(arguments: [id, text])
                }
            }
        }
        chunkInsertMilliseconds += elapsed
        nextID = lastID + 1
    }
    report["chunk_insert_ms"] = chunkInsertMilliseconds
    report["chunk_insert_per_s"] = Double(options.chunks) / (chunkInsertMilliseconds / 1_000)

    // Inserimento dei nomi dei file, indicizzati con il tokenizer trigram.
    var fileInsertMilliseconds = 0.0
    nextID = 1
    while nextID <= options.files {
        let lastID = min(nextID + batchSize - 1, options.files)
        let batch = (nextID...lastID).map { id -> (Int, String, String) in
            let name = corpus.fileName(&rng)
            return (id, "/Users/mosaic/\(corpus.word(&rng))/\(corpus.word(&rng))/\(name)", name)
        }
        for (id, _, name) in batch where id % 1_000 == 0 { sampleNames.append(name) }
        let (_, elapsed) = try timed {
            try pool.write { db in
                let insertFile = try db.cachedStatement(sql: "INSERT INTO file(id, path, name, size, mtime) VALUES (?, ?, ?, ?, ?)")
                let insertName = try db.cachedStatement(sql: "INSERT INTO name_fts(rowid, name) VALUES (?, ?)")
                for (id, path, name) in batch {
                    try insertFile.execute(arguments: [id, path, name, id * 37 % 5_000_000, 1_700_000_000 + id])
                    try insertName.execute(arguments: [id, name])
                }
            }
        }
        fileInsertMilliseconds += elapsed
        nextID = lastID + 1
    }
    report["file_insert_ms"] = fileInsertMilliseconds
    report["file_insert_per_s"] = Double(options.files) / (fileInsertMilliseconds / 1_000)

    try pool.writeWithoutTransaction { db in try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)") }
    report["database_bytes"] = fileSize(databaseURL)

    // Interrogazioni full-text e sui nomi, a cache calda.
    let queries = buildQueries(corpus: corpus, samples: sampleTexts, count: options.queriesPerKind, rng: &rng)
    var warm: [String: Any] = [:]
    for (kind, list) in queries {
        var samples: [Double] = []
        var hits = 0
        for query in list {
            let (rows, elapsed) = try timed { try pool.read { db in try Row.fetchAll(db, sql: fullTextSQL, arguments: [query]) } }
            samples.append(elapsed)
            if !rows.isEmpty { hits += 1 }
        }
        var summary: [String: Any] = latencySummary(samples)
        summary["queries_with_results"] = hits
        warm[kind] = summary
    }
    let nameQueries = buildNameQueries(samples: sampleNames, count: options.queriesPerKind, rng: &rng)
    var nameSamples: [Double] = []
    var nameHits = 0
    for query in nameQueries {
        let (rows, elapsed) = try timed { try pool.read { db in try Row.fetchAll(db, sql: nameSQL, arguments: [query]) } }
        nameSamples.append(elapsed)
        if !rows.isEmpty { nameHits += 1 }
    }
    var nameSummary: [String: Any] = latencySummary(nameSamples)
    nameSummary["queries_with_results"] = nameHits
    warm["name_trigram"] = nameSummary
    report["warm_queries"] = warm

    // Aggiornamento di 1.000 blocchi: rimozione dall'indice e reinserimento.
    let (_, updateMilliseconds) = try timed {
        try pool.write { db in
            for _ in 0..<1_000 {
                let id = Int.random(in: 1...options.chunks, using: &rng)
                let old = try String.fetchOne(db, sql: "SELECT text FROM chunk WHERE id = ?", arguments: [id]) ?? ""
                let new = corpus.text(words: options.wordsPerChunk, &rng)
                try db.execute(sql: "INSERT INTO chunk_fts(chunk_fts, rowid, text) VALUES('delete', ?, ?)", arguments: [id, old])
                try db.execute(sql: "UPDATE chunk SET text = ? WHERE id = ?", arguments: [new, id])
                try db.execute(sql: "INSERT INTO chunk_fts(rowid, text) VALUES (?, ?)", arguments: [id, new])
            }
        }
    }
    report["update_1000_chunks_ms"] = updateMilliseconds
    report["peak_resident_bytes"] = peakResidentBytes()

    try pool.close()

    // Riapertura: tempo fino al primo risultato.
    let firstQuery = queries["single_medium"]?.first ?? "\"\(corpus.words[1_000])\""
    let (_, reopenMilliseconds) = try timed {
        let reopened = try DatabasePool(path: databaseURL.path, configuration: configuration(for: options.mode))
        _ = try reopened.read { db in try Row.fetchAll(db, sql: fullTextSQL, arguments: [firstQuery]) }
        try reopened.close()
    }
    report["reopen_first_query_ms"] = reopenMilliseconds

    if options.mode.isEncrypted {
        report["security_checks"] = try securityChecks(databaseURL: databaseURL, directory: directory, mode: options.mode)
    }

    let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    if let output = options.output {
        try json.write(to: output)
    }
    FileHandle.standardOutput.write(json)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

let fullTextSQL = """
    SELECT rowid, bm25(chunk_fts) AS rank, snippet(chunk_fts, 0, '[', ']', '…', 10) AS excerpt
    FROM chunk_fts WHERE chunk_fts MATCH ? ORDER BY rank LIMIT 20
    """

let nameSQL = "SELECT rowid FROM name_fts WHERE name_fts MATCH ? LIMIT 50"

func engineInfo(_ db: Database) throws -> [String: Any] {
    let options = try String.fetchAll(db, sql: "PRAGMA compile_options")
    var info: [String: Any] = [
        "sqlite_version": try String.fetchOne(db, sql: "SELECT sqlite_version()") ?? "?",
        "fts5": options.contains("ENABLE_FTS5"),
        "load_extension_omitted": options.contains("OMIT_LOAD_EXTENSION"),
    ]
    if let version = try String.fetchOne(db, sql: "PRAGMA cipher_version") { info["cipher_version"] = version }
    if let provider = try String.fetchOne(db, sql: "PRAGMA cipher_provider") { info["cipher_provider"] = provider }
    if let pageSize = try Int.fetchOne(db, sql: "PRAGMA cipher_page_size") { info["cipher_page_size"] = pageSize }
    if let memorySecurity = try Int.fetchOne(db, sql: "PRAGMA cipher_memory_security") { info["cipher_memory_security"] = memorySecurity }
    return info
}

func quoted(_ term: String) -> String { "\"\(term)\"" }

func buildQueries(corpus: Corpus, samples: [String], count: Int, rng: inout SplitMix64) -> [String: [String]] {
    func word(inRanks range: ClosedRange<Int>) -> String { corpus.words[Int.random(in: range, using: &rng)] }
    let accented = corpus.words[1_000..<20_000].filter { $0.unicodeScalars.contains { $0.value > 127 } }
    var queries: [String: [String]] = [:]
    queries["single_common"] = (0..<count).map { _ in quoted(word(inRanks: 20...200)) }
    queries["single_medium"] = (0..<count).map { _ in quoted(word(inRanks: 1_000...3_000)) }
    queries["single_rare"] = (0..<count).map { _ in quoted(word(inRanks: 15_000...35_000)) }
    queries["and_two_medium"] = (0..<count).map { _ in "\(quoted(word(inRanks: 500...3_000))) \(quoted(word(inRanks: 500...3_000)))" }
    queries["phrase_from_text"] = (0..<count).map { _ in
        let words = samples.randomElement(using: &rng)!.split(separator: " ")
        let start = Int.random(in: 0..<(words.count - 1), using: &rng)
        return quoted("\(words[start]) \(words[start + 1])")
    }
    queries["prefix_3"] = (0..<count).map { _ in "\(quoted(String(word(inRanks: 1_000...5_000).prefix(3))))*" }
    queries["accent_insensitive"] = (0..<count).map { _ in
        quoted(accented.randomElement(using: &rng)!.folding(options: .diacriticInsensitive, locale: nil))
    }
    return queries
}

func buildNameQueries(samples: [String], count: Int, rng: inout SplitMix64) -> [String] {
    (0..<count).map { _ in
        let name = Array(samples.randomElement(using: &rng)!)
        let start = Int.random(in: 0..<(name.count - 4), using: &rng)
        return quoted(String(name[start..<(start + 4)]))
    }
}

/// Verifiche di sicurezza sui database cifrati: intestazione illeggibile, apertura
/// negata senza chiave o con chiave sbagliata, backup cifrato come richiesto da MOS-DM-001 §6.
func securityChecks(databaseURL: URL, directory: URL, mode: BenchMode) throws -> [String: Any] {
    var checks: [String: Any] = [:]
    let header = try FileHandle(forReadingFrom: databaseURL).read(upToCount: 16) ?? Data()
    checks["plaintext_header"] = header == Data("SQLite format 3\u{0}".utf8)

    func canRead(_ configuration: Configuration) -> Bool {
        (try? DatabaseQueue(path: databaseURL.path, configuration: configuration).read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master")
        }) != nil
    }
    checks["readable_without_key"] = canRead(Configuration())
    var wrongKey = Configuration()
    wrongKey.prepareDatabase { db in try db.execute(sql: "PRAGMA key = \"x'\(String(repeating: "11", count: 32))'\"") }
    checks["readable_with_wrong_key"] = canRead(wrongKey)

    // Backup su un file cifrato con la stessa chiave, come quello previsto prima delle migrazioni.
    let source = try DatabaseQueue(path: databaseURL.path, configuration: configuration(for: mode))
    let backupURL = directory.appending(path: "backup.sqlite")
    let destination = try DatabaseQueue(path: backupURL.path, configuration: configuration(for: mode))
    let (_, backupMilliseconds) = try timed { try source.backup(to: destination) }
    let sourceCount = try source.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM chunk") }
    let backupCount = try destination.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM chunk") }
    let backupHeader = try FileHandle(forReadingFrom: backupURL).read(upToCount: 16) ?? Data()
    checks["backup_ms"] = backupMilliseconds
    checks["backup_rows_match"] = sourceCount == backupCount
    checks["backup_plaintext_header"] = backupHeader == Data("SQLite format 3\u{0}".utf8)
    try source.close()
    try destination.close()
    return checks
}
