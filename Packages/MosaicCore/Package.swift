// swift-tools-version:6.1
// Foundations shared by every Mosaic module: identifiers, errors, events,
// the command registry and secret storage. System frameworks only.

import PackageDescription

let package = Package(
    name: "MosaicCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MosaicCore", targets: ["MosaicCore"]),
    ],
    targets: [
        .target(name: "MosaicCore"),
        .testTarget(name: "MosaicCoreTests", dependencies: ["MosaicCore"]),
    ],
    swiftLanguageModes: [.v6]
)
