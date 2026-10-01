import Foundation

do {
    try runBenchmark(BenchOptions.parse(CommandLine.arguments, defaultMode: .system))
} catch {
    FileHandle.standardError.write(Data("S1Plain: \(error)\n".utf8))
    exit(1)
}
