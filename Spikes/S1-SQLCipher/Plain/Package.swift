// swift-tools-version:6.1
// Spike S1, variante di riferimento: GRDB ufficiale con l'SQLite di sistema.

import PackageDescription

let package = Package(
    name: "S1Plain",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "S1Plain",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
    ]
)
