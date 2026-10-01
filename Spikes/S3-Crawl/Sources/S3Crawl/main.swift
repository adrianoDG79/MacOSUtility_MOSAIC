import Foundation

// Usage:
//   S3Crawl crawl <root> [--exclude <path>]...   crawl with both methods, twice each
//   S3Crawl synthetic <scratch dir>                build a 300,000-file tree, crawl it, delete it
//   S3Crawl fsevents <scratch dir>                 replay test
// Output is aggregate JSON: no file names or paths.

func peakResidentMB() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_maxrss) / 1_048_576
}

func measure(_ label: String, _ body: () -> CrawlStats) -> [String: Any] {
    let start = ContinuousClock.now
    let stats = body()
    let elapsed = ContinuousClock.now - start
    let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    let entries = stats.files + stats.directories + stats.symlinks + stats.other
    return ["method": label, "seconds": seconds, "entries_per_second": Double(entries) / seconds,
            "peak_resident_mb": peakResidentMB(), "stats": stats.json]
}

func emit(_ object: Any) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func crawlBothWays(root: String, rules: CrawlRules) -> [[String: Any]] {
    // Alternating runs; the first pass also warms the file system cache.
    (1...2).flatMap { run in
        [measure("getattrlistbulk run \(run)") { crawlWithBulkAttributes(root: root, rules: rules) },
         measure("FileManager run \(run)") { crawlWithFileManager(root: root, rules: rules) }]
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first, arguments.count >= 2 else {
    FileHandle.standardError.write(Data("uso: S3Crawl crawl|synthetic|fsevents <percorso>\n".utf8))
    exit(2)
}
let policyApplied = disableDatalessMaterialization()

switch command {
case "crawl":
    var excluded: Set<String> = []
    var iterator = arguments.dropFirst(2).makeIterator()
    while let flag = iterator.next() {
        if flag == "--exclude", let path = iterator.next() { excluded.insert(path) }
    }
    let rules = CrawlRules(excludedPaths: excluded)
    emit(["dataless_policy_off": policyApplied, "runs": crawlBothWays(root: arguments[1], rules: rules)])

case "synthetic":
    let root = URL(filePath: arguments[1]).appending(path: "s3-synthetic-\(UUID().uuidString)")
    let start = ContinuousClock.now
    let created = try makeSyntheticTree(at: root, directories: 100, subdirectories: 30, filesPerDirectory: 100)
    let creation = ContinuousClock.now - start
    let runs = crawlBothWays(root: root.path, rules: CrawlRules(excludedPaths: []))
    try? FileManager.default.removeItem(at: root)
    emit(["files_created": created, "creation_seconds": Double(creation.components.seconds), "runs": runs])

case "fsevents":
    let root = URL(filePath: arguments[1]).appending(path: "s3-fsevents-\(UUID().uuidString)")
    let result = try runFSEventsReplay(in: root)
    try? FileManager.default.removeItem(at: root)
    emit(result)

default:
    FileHandle.standardError.write(Data("comando sconosciuto: \(command)\n".utf8))
    exit(2)
}
