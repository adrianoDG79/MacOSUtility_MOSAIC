// swift-tools-version:6.1
// Spike S7: on-device Foundation Models for natural-language search intents.

import PackageDescription

let package = Package(
    name: "S7FoundationModels",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "S7FoundationModels"),
    ],
    swiftLanguageModes: [.v6]
)
