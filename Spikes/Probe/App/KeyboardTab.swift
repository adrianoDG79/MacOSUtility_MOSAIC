import SwiftUI

/// Spike S4 user interface. The test protocol is on screen, in Italian.
struct KeyboardTab: View {
    @State private var monitor = KeyboardMonitor()
    @State private var testText = ""
    @State private var saved = ""

    var body: some View {
        Form {
            Section("1. Tastiere collegate (nessun permesso)") {
                ForEach(monitor.devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.product).bold()
                        Text("\(device.manufacturer) · \(device.transport) · \(device.builtIn ? "interna" : "esterna") · VID \(device.vendorID) PID \(device.productID) · numero di serie \(device.serial)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Collega e scollega una tastiera esterna: gli eventi compaiono qui sotto.")
                    .foregroundStyle(.secondary)
                ForEach(Array(monitor.log.suffix(8).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption.monospaced())
                }
            }
            Section("2. Tastiera in uso (Monitoraggio dell'input)") {
                LabeledContent("Permesso", value: Permissions.inputMonitoring)
                Button("Avvia il rilevamento") { monitor.startActivityMonitor() }
                LabeledContent("Stato", value: monitor.hidStatus)
                LabeledContent("Tastiera attiva", value: monitor.activeDevice)
                LabeledContent("Tasti rilevati (solo il conteggio)", value: "\(monitor.keyEventsSeen)")
            }
            Section("3. Layout per tastiera") {
                ForEach(monitor.devices) { device in
                    Picker(device.product, selection: Binding(
                        get: { monitor.mapping[device.id] ?? "" },
                        set: { monitor.mapping[device.id] = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("—").tag("")
                        ForEach(monitor.sources) { source in
                            Text(source.name).tag(source.id)
                        }
                    }
                }
                Toggle("Cambia layout automaticamente", isOn: $monitor.autoSwitch)
                LabeledContent("Layout corrente", value: monitor.currentSource)
                LabeledContent("Cambi misurati", value: "\(monitor.switchLatencies.count)")
                if let median = monitor.switchLatencies.sorted().dropFirst(monitor.switchLatencies.count / 2).first {
                    LabeledContent("Latenza del cambio", value: String(format: "mediana %.1f ms · massimo %.1f ms", median, monitor.switchLatencies.max() ?? 0))
                }
            }
            Section("4. Test del primo tasto") {
                Text("""
                    1. Nella sezione 3 scegli Italiano – Pro per la tastiera interna e U.S. per quella esterna.
                    2. Attiva il cambio automatico e avvia il rilevamento (sezione 2).
                    3. Nel campo qui sotto premi 5 volte il tasto a destra della L sulla tastiera interna, \
                    poi 5 volte lo stesso tasto sulla tastiera esterna. Ripeti per tre giri.
                    """)
                    .foregroundStyle(.secondary)
                TextField("Scrivi qui", text: $testText, axis: .vertical)
                    .lineLimit(3...6)
                    .onAppear { monitor.startKeystrokeTest() }
                let firsts = monitor.keystrokes.filter { $0.firstAfterSwitch && $0.correct != nil }
                let others = monitor.keystrokes.filter { !$0.firstAfterSwitch && $0.correct != nil }
                LabeledContent("Primo tasto dopo il cambio, carattere sbagliato", value: "\(firsts.filter { $0.correct == false }.count) su \(firsts.count)")
                LabeledContent("Altri tasti, carattere sbagliato", value: "\(others.filter { $0.correct == false }.count) su \(others.count)")
                Button("Azzera il test") {
                    monitor.resetKeystrokeTest()
                    testText = ""
                }
            }
            Section("5. Cambio automatico per documento (macOS)") {
                LabeledContent("Impostazione di sistema", value: monitor.perContextInput)
            }
            Section {
                Button("Salva risultati") {
                    saved = ResultStore.save(monitor.summary, as: "s4-keyboard")?.path ?? "errore di salvataggio"
                }
                if !saved.isEmpty {
                    Text(saved).font(.caption).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}
