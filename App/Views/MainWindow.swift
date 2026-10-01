import AppKit
import MosaicCore
import SwiftUI

/// M0 window: states honestly that there are no user features yet and shows
/// the live status of the foundations.
struct MainWindow: View {
    static let id = "main"

    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Text("Mosaic è nella fase M0: fondamenta e verifiche tecniche. Le funzioni per l'utente arrivano da M1.")
                    .foregroundStyle(.secondary)
            }

            switch model.state {
            case .starting:
                Section { ProgressView("Avvio delle fondamenta…") }
            case .failed(let message):
                Section("Errore") {
                    Text(message)
                        .textSelection(.enabled)
                }
            case .ready(let status):
                Section("Database di configurazione") {
                    LabeledContent("Cifratura", value: status.engine.cipherVersion.map { "SQLCipher \($0)" } ?? "assente")
                    LabeledContent("Motore SQLite", value: status.engine.sqliteVersion)
                    LabeledContent("Migrazioni applicate", value: status.engine.appliedMigrations.joined(separator: ", "))
                    LabeledContent("Percorso") {
                        Text(status.databasePath)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                Section("Questo Mac") {
                    LabeledContent("Nome", value: status.device.name)
                    LabeledContent("Modello", value: status.device.model)
                    LabeledContent("Identificativo") {
                        Text(status.device.id.description)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                Section("Attività in background") {
                    LabeledContent("Lavori in coda", value: "\(status.jobs.queued.values.reduce(0, +))")
                    LabeledContent("Lavori in esecuzione", value: "\(status.jobs.running.values.reduce(0, +))")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 380)
        .task { await model.refresh() }
        .onAppear { NSApp.setActivationPolicy(.regular) }
        // With the window closed Mosaic lives only in the menu bar (D2).
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }
}
