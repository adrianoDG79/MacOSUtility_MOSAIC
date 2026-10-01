import AppKit

/// Lifecycle rules of D2: closing the window keeps Mosaic in the menu bar;
/// an explicit quit stops every background activity before exiting.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await model.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = model
        Task {
            // Give background work up to three seconds to stop cleanly.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await model.shutdown() }
                group.addTask { try? await Task.sleep(for: .seconds(3)) }
                await group.next()
                group.cancelAll()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
