import SwiftUI

/// Mosaic Probe: one app for the interactive spikes of M0 (S2, S4, S5, S8),
/// so permissions are granted once. Results go to
/// ~/Library/Application Support/MosaicProbe as aggregate JSON.
@main
struct ProbeApp: App {
    init() {
        // As in Mosaic's extractor: never download cloud-only files as a side effect.
        ProbeIO.disableDatalessMaterialization()
    }

    var body: some Scene {
        WindowGroup("Mosaic Probe") {
            TabView {
                SigningTab().tabItem { Text("Firma e permessi (S8)") }
                XPCTab().tabItem { Text("XPC e TCC (S2)") }
                MailTab().tabItem { Text("Apple Mail (S5)") }
                KeyboardTab().tabItem { Text("Tastiere (S4)") }
            }
            .frame(minWidth: 820, minHeight: 620)
            .padding()
        }
    }
}
