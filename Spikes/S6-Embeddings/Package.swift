// swift-tools-version:6.1
// Spike S6: corpus extraction and Apple NLContextualEmbedding vectors.
// Python scripts in this folder generate queries and score every model.

import PackageDescription

let package = Package(
    name: "S6Embeddings",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "S6Embeddings"),
    ],
    swiftLanguageModes: [.v6]
)
