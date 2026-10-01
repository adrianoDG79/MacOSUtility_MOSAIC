import AppKit
import SwiftUI

/// Spike S2: TCC attribution of embedded XPC services, descriptor passing into
/// a sandboxed service, and the dataless policy on cloud-only files.
struct XPCTab: View {
    @State private var reader = ProbeServiceClient(serviceName: "it.mosaic.probe.reader")
    @State private var sandboxed = ProbeServiceClient(serviceName: "it.mosaic.probe.sandboxed")
    @State private var results: [String: String] = [:]
    @State private var busy = false

    var body: some View {
        Form {
            Section("1. Attribuzione dei permessi ai servizi XPC") {
                Text("Richiede che Mosaic Probe abbia l'accesso completo al disco. Legge la cartella di Mail dall'app e dai due servizi.")
                    .foregroundStyle(.secondary)
                Button("Esegui") { run(attribution) }
                    .disabled(busy)
                resultRows(["app", "reader", "sandboxed", "attribution"])
            }
            Section("2. Servizio in sandbox con descrittore di file") {
                Text("Scegli un file qualsiasi, per esempio un PDF. L'app lo apre e passa il descrittore al servizio in sandbox.")
                    .foregroundStyle(.secondary)
                Button("Scegli un file…") { choose { url in run { await descriptorTest(url) } } }
                    .disabled(busy)
                resultRows(["fd_read", "sandbox_open_path", "sandbox_network", "reader_network"])
            }
            Section("3. File solo online (Google Drive)") {
                Text("Scegli in Google Drive un file che non è stato scaricato (icona a forma di nuvola). Non deve essere scaricato.")
                    .foregroundStyle(.secondary)
                Button("Scegli un file solo online…") { choose { url in run { await datalessTest(url) } } }
                    .disabled(busy)
                resultRows(["dataless_before", "app_read", "sandbox_read", "dataless_after"])
            }
            Section {
                Button("Salva risultati") {
                    let url = ResultStore.save(results, as: "s2-xpc")
                    results["saved"] = url?.path ?? "errore di salvataggio"
                }
                resultRows(["saved"])
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func resultRows(_ keys: [String]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let value = results[key] {
                LabeledContent(key, value: value)
                    .textSelection(.enabled)
            }
        }
    }

    private func run(_ operation: @escaping () async -> Void) {
        busy = true
        Task {
            await operation()
            busy = false
        }
    }

    private func choose(_ handler: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            handler(url)
        }
    }

    private func attribution() async {
        let path = Permissions.mailDirectory
        let app = ProbeIO.listDirectory(path)
        let readerResult = await reader.listDirectory(path)
        let sandboxedResult = await sandboxed.listDirectory(path)
        results["app"] = ProbeIO.describeError(app.1)
        results["reader"] = "\(ProbeIO.describeError(readerResult.1)) — \(await reader.describe())"
        results["sandboxed"] = "\(ProbeIO.describeError(sandboxedResult.1)) — \(await sandboxed.describe())"
        switch (app.1, readerResult.1) {
        case (0, 0): results["attribution"] = "il servizio XPC eredita l'accesso completo al disco dell'app"
        case (0, _): results["attribution"] = "l'app ha l'accesso, il servizio XPC no: attribuzione NON ereditata"
        default: results["attribution"] = "l'app non ha ancora l'accesso completo al disco: concedilo e riapri Mosaic Probe"
        }
    }

    private func descriptorTest(_ url: URL) async {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            results["fd_read"] = "l'app non riesce ad aprire il file"
            return
        }
        let read = await sandboxed.read(handle)
        results["fd_read"] = read.1 == 0 ? "letti \(read.0) byte dal descrittore" : ProbeIO.describeError(read.1)
        results["sandbox_open_path"] = "apertura diretta del percorso: " + ProbeIO.describeError(await sandboxed.openPath(url.path))
        results["sandbox_network"] = "rete dalla sandbox: " + ProbeIO.describeError(await sandboxed.connectLoopback())
        results["reader_network"] = "rete senza sandbox: " + ProbeIO.describeError(await reader.connectLoopback())
    }

    private func datalessTest(_ url: URL) async {
        func isDataless() -> String {
            var info = stat()
            guard lstat(url.path, &info) == 0 else { return "stat fallito: \(ProbeIO.describeError(errno))" }
            return info.st_flags & 0x4000_0000 != 0 ? "sì (solo online)" : "no (già scaricato)"
        }
        results["dataless_before"] = isDataless()
        let descriptor = open(url.path, O_RDONLY)
        if descriptor < 0 {
            results["app_read"] = "apertura: " + ProbeIO.describeError(errno)
        } else {
            results["app_read"] = "lettura nell'app: " + ProbeIO.describeError(ProbeIO.read(descriptor: descriptor).1)
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            let sandboxRead = await sandboxed.read(handle)
            results["sandbox_read"] = "lettura nel servizio in sandbox: " + ProbeIO.describeError(sandboxRead.1)
        }
        results["dataless_after"] = isDataless()
    }
}
