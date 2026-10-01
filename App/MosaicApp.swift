import SwiftUI

@main
struct MosaicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Mosaic", id: MainWindow.id) {
            MainWindow()
                .environment(appDelegate.model)
        }
        .defaultSize(width: 640, height: 460)

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }

        // Placeholder symbol until the icon exploration of M1 (ADR-017).
        MenuBarExtra("Mosaic", systemImage: "rectangle.3.group") {
            MenuBarMenu()
                .environment(appDelegate.model)
        }
    }
}
