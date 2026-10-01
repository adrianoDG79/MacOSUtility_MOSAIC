// swift-tools-version:6.1
// Platform services shared by feature modules: background jobs now; resource
// management, telemetry and permissions in later milestones.

import PackageDescription

let package = Package(
    name: "MosaicPlatform",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MosaicPlatform", targets: ["MosaicPlatform"]),
    ],
    dependencies: [
        .package(path: "../MosaicCore"),
    ],
    targets: [
        .target(name: "MosaicPlatform", dependencies: [.product(name: "MosaicCore", package: "MosaicCore")]),
        .testTarget(name: "MosaicPlatformTests", dependencies: ["MosaicPlatform"]),
    ],
    swiftLanguageModes: [.v6]
)
