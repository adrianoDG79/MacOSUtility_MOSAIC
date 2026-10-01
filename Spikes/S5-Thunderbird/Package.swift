// swift-tools-version:6.1
// Spike S5, Thunderbird part: reader prototype tested on a fixture profile
// built from the documented formats (D3: Thunderbird is not installed here).

import PackageDescription

let package = Package(
    name: "S5Thunderbird",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ThunderbirdSpike"),
        .testTarget(name: "ThunderbirdSpikeTests", dependencies: ["ThunderbirdSpike"]),
    ],
    swiftLanguageModes: [.v6]
)
