// swift-tools-version:6.1
// Spike S1, variante SQLCipher: usa la copia di GRDB preparata da scripts/vendor-grdb.sh.

import PackageDescription

let package = Package(
    name: "S1Cipher",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../Vendor/GRDB.swift"),
    ],
    targets: [
        .executableTarget(
            name: "S1Cipher",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: [.define("MOSAIC_SQLCIPHER")]
        ),
    ]
)
