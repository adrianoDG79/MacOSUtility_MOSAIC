// swift-tools-version:6.1
// Spike S3: bulk metadata crawl and FSEvents replay after a quit.

import PackageDescription

let package = Package(
    name: "S3Crawl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "S3Crawl"),
    ],
    swiftLanguageModes: [.v6]
)
