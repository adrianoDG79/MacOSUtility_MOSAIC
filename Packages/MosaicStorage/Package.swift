// swift-tools-version:6.1
// Mosaic's SQLite stores (ADR-004), encrypted with SQLCipher (ADR-006).
// GRDB comes from Vendor/GRDB.swift, prepared by scripts/vendor-grdb.sh.

import PackageDescription

let package = Package(
    name: "MosaicStorage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MosaicStorage", targets: ["MosaicStorage"]),
    ],
    dependencies: [
        .package(path: "../MosaicCore"),
        .package(path: "../../Vendor/GRDB.swift"),
    ],
    targets: [
        .target(
            name: "MosaicStorage",
            dependencies: [
                .product(name: "MosaicCore", package: "MosaicCore"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(name: "MosaicStorageTests", dependencies: ["MosaicStorage"]),
    ],
    swiftLanguageModes: [.v6]
)
