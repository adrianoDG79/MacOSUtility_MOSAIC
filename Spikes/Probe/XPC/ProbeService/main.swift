import Foundation

// Shared by both XPC targets: ProbeReader (unsandboxed) and ProbeSandboxed
// (App Sandbox, no network, no file entitlements). Only entitlements differ.

final class ProbeService: NSObject, ProbeServiceProtocol {
    func listDirectory(_ path: String, reply: @escaping (Int, Int32) -> Void) {
        let (count, code) = ProbeIO.listDirectory(path)
        reply(count, code)
    }

    func openPath(_ path: String, reply: @escaping (Int32) -> Void) {
        reply(ProbeIO.openPath(path))
    }

    func read(_ handle: FileHandle, reply: @escaping (Int, Int32) -> Void) {
        let (count, code) = ProbeIO.read(descriptor: handle.fileDescriptor)
        reply(count, code)
    }

    func connectLoopback(reply: @escaping (Int32) -> Void) {
        reply(ProbeIO.connectLoopback())
    }

    func describe(reply: @escaping (String) -> Void) {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        reply("pid \(getpid()), \(sandboxed ? "in sandbox" : "senza sandbox")")
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ProbeServiceProtocol.self)
        connection.exportedObject = ProbeService()
        connection.resume()
        return true
    }
}

ProbeIO.disableDatalessMaterialization()
let delegate = ListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
