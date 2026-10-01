import AppKit
import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Mosaic — fondamenta (M0)")
        Divider()
        Button("Apri Mosaic") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: MainWindow.id)
            NSApp.activate()
        }
        SettingsLink {
            Text("Impostazioni…")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Esci da Mosaic") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
