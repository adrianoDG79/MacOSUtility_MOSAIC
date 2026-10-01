// swift-tools-version:6.1
// Manifesto sostitutivo per GRDB v7.11.1 compilato con SQLCipher (ADR-006).
//
// GRDB documenta che, con SwiftPM, SQLCipher richiede una copia di GRDB con il
// Package.swift modificato secondo i commenti "GRDB+SQLCipher" del manifesto
// originale. Questo file applica esattamente quelle modifiche e rimuove il
// target dei test di GRDB, che Mosaic non compila.
//
// scripts/vendor-grdb.sh lo copia in Vendor/GRDB.swift. Va aggiornato insieme
// a GRDB_TAG e GRDB_COMMIT in quello script.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_SNAPSHOT"),
    .define("SQLITE_HAS_CODEC"),
    .define("SQLCipher"),
]

let cSettings: [CSetting] = [
    .define("SQLITE_HAS_CODEC"),
]

let package = Package(
    name: "GRDB",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "GRDB", targets: ["GRDB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", exact: "4.19.0"),
    ],
    targets: [
        .target(
            name: "GRDBSQLCipher",
            dependencies: [.product(name: "SQLCipher", package: "SQLCipher.swift")]
        ),
        .target(
            name: "GRDB",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift"),
                .target(name: "GRDBSQLCipher"),
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]),
    ],
    swiftLanguageModes: [.v6]
)
