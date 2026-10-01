import Foundation

do {
    try runBenchmark(BenchOptions.parse(CommandLine.arguments, defaultMode: .cipherRawKey))
} catch {
    FileHandle.standardError.write(Data("S1Cipher: \(error)\n".utf8))
    exit(1)
}
