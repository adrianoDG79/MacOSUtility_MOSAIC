import IOKit.hid
import Network
import SwiftUI
import SystemConfiguration

/// Spike S8: signature of this build, permission state, and a history across
/// rebuilds to see whether TCC grants survive them.
struct SigningTab: View {
    @State private var info = SigningInfo.current
    @State private var fullDiskAccess = Permissions.hasFullDiskAccess
    @State private var inputMonitoring = Permissions.inputMonitoring
    @State private var localNetwork = "non verificata"
    @State private var history: [[String: Any]] = (ResultStore.load("signing-history") as? [[String: Any]]) ?? []

    var body: some View {
        Form {
            Section("Firma di questa build") {
                LabeledContent("Identificatore", value: info.identifier)
                LabeledContent("Team", value: info.teamIdentifier)
                LabeledContent("Firma ad hoc", value: info.adhoc ? "sì" : "no")
                LabeledContent("Hardened Runtime", value: info.hardenedRuntime ? "attivo" : "non attivo")
                LabeledContent("Impronta (cdhash)", value: info.cdhash)
                LabeledContent("Posizione", value: Bundle.main.bundlePath)
            }
            Section("Permessi") {
                LabeledContent("Accesso completo al disco", value: fullDiskAccess ? "concesso" : "mancante")
                Button("Apri Accesso completo al disco") { Permissions.openFullDiskAccessSettings() }
                LabeledContent("Monitoraggio dell'input", value: inputMonitoring)
                HStack {
                    Button("Richiedi") {
                        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                        inputMonitoring = Permissions.inputMonitoring
                    }
                    Button("Apri Monitoraggio dell'input") { Permissions.openInputMonitoringSettings() }
                }
                LabeledContent("Rete locale", value: localNetwork)
                Button("Verifica rete locale") {
                    localNetwork = "verifica in corso…"
                    Task { localNetwork = await LocalNetworkProbe.run() }
                }
                Button("Aggiorna stati") { refresh() }
            }
            Section("Storico delle build") {
                Button("Registra questa build") { record() }
                ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, entry in
                    Text(summary(entry))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func refresh() {
        info = SigningInfo.current
        fullDiskAccess = Permissions.hasFullDiskAccess
        inputMonitoring = Permissions.inputMonitoring
    }

    private func record() {
        refresh()
        history.append([
            "date": ISO8601DateFormatter().string(from: Date()),
            "cdhash": info.cdhash,
            "team": info.teamIdentifier,
            "adhoc": info.adhoc,
            "hardened_runtime": info.hardenedRuntime,
            "in_applications": Bundle.main.bundlePath.hasPrefix("/Applications/"),
            "full_disk_access": fullDiskAccess,
            "input_monitoring": inputMonitoring,
            "local_network": localNetwork,
        ])
        _ = ResultStore.save(history, as: "signing-history")
    }

    private func summary(_ entry: [String: Any]) -> String {
        let keys = ["date", "cdhash", "team", "adhoc", "hardened_runtime", "in_applications", "full_disk_access", "input_monitoring", "local_network"]
        return keys.map { "\($0)=\(entry[$0] ?? "-")" }.joined(separator: "  ")
    }
}

/// Tries a TCP connection to the router, which macOS 15+ gates behind the
/// local network privacy permission.
enum LocalNetworkProbe {
    static func routerAddress() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "MosaicProbe" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else { return nil }
        return value["Router"] as? String
    }

    @MainActor
    static func run() async -> String {
        guard let router = routerAddress() else { return "nessun router IPv4" }
        let connection = NWConnection(host: NWEndpoint.Host(router), port: 80, using: .tcp)
        return await withCheckedContinuation { continuation in
            var finished = false
            func finish(_ result: String) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                let denied = connection.currentPath?.unsatisfiedReason == .localNetworkDenied
                switch state {
                case .ready:
                    finish("consentita (router raggiunto)")
                case .waiting(let error), .failed(let error):
                    if denied {
                        finish("negata dalla privacy della rete locale")
                    } else if case .posix(let code) = error, code == .ECONNREFUSED {
                        finish("consentita (router raggiungibile, porta chiusa)")
                    } else {
                        finish("errore: \(error)")
                    }
                default:
                    break
                }
            }
            connection.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { finish("nessuna risposta entro 6 s") }
        }
    }
}
