import AppKit
import Foundation
import IOKit.hid
import Security

/// Results are saved as JSON in ~/Library/Application Support/MosaicProbe,
/// with aggregate values only.
enum ResultStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("MosaicProbe", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ object: Any, as name: String) -> URL? {
        let url = directory.appendingPathComponent("\(name).json")
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              (try? data.write(to: url)) != nil else { return nil }
        return url
    }

    static func load(_ name: String) -> Any? {
        let url = directory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

enum Permissions {
    /// Full Disk Access probe: ~/Library/Mail is readable only with it.
    static var mailDirectory: String {
        NSHomeDirectory() + "/Library/Mail"
    }

    static var hasFullDiskAccess: Bool {
        ProbeIO.listDirectory(mailDirectory).1 == 0
    }

    static var inputMonitoring: String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return "concesso"
        case kIOHIDAccessTypeDenied: return "negato"
        default: return "non ancora richiesto"
        }
    }

    static func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    static func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
}

/// Code signature of the running app (spike S8).
struct SigningInfo {
    let identifier: String
    let teamIdentifier: String
    let adhoc: Bool
    let hardenedRuntime: Bool
    let cdhash: String

    static var current: SigningInfo {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else {
            return SigningInfo(identifier: "?", teamIdentifier: "?", adhoc: false, hardenedRuntime: false, cdhash: "?")
        }
        let flags = (dictionary[kSecCodeInfoFlags as String] as? UInt32) ?? 0
        let hash = (dictionary[kSecCodeInfoUnique as String] as? Data)?.map { String(format: "%02x", $0) }.joined() ?? "?"
        return SigningInfo(
            identifier: dictionary[kSecCodeInfoIdentifier as String] as? String ?? "?",
            teamIdentifier: dictionary[kSecCodeInfoTeamIdentifier as String] as? String ?? "nessuno (firma ad hoc)",
            adhoc: flags & 0x2 != 0,
            hardenedRuntime: flags & 0x10000 != 0,
            cdhash: String(hash.prefix(16))
        )
    }
}

/// Async wrapper around one of the probe XPC services.
final class ProbeServiceClient {
    private let connection: NSXPCConnection

    init(serviceName: String) {
        connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: ProbeServiceProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    private func proxy(_ onError: @escaping (Error) -> Void) -> ProbeServiceProtocol {
        connection.remoteObjectProxyWithErrorHandler(onError) as! ProbeServiceProtocol
    }

    func describe() async -> String {
        await withCheckedContinuation { continuation in
            proxy { continuation.resume(returning: "errore XPC: \($0.localizedDescription)") }.describe { continuation.resume(returning: $0) }
        }
    }

    func listDirectory(_ path: String) async -> (Int, Int32) {
        await withCheckedContinuation { continuation in
            proxy { _ in continuation.resume(returning: (0, -1)) }.listDirectory(path) { continuation.resume(returning: ($0, $1)) }
        }
    }

    func openPath(_ path: String) async -> Int32 {
        await withCheckedContinuation { continuation in
            proxy { _ in continuation.resume(returning: -1) }.openPath(path) { continuation.resume(returning: $0) }
        }
    }

    func read(_ handle: FileHandle) async -> (Int, Int32) {
        await withCheckedContinuation { continuation in
            proxy { _ in continuation.resume(returning: (0, -1)) }.read(handle) { continuation.resume(returning: ($0, $1)) }
        }
    }

    func connectLoopback() async -> Int32 {
        await withCheckedContinuation { continuation in
            proxy { _ in continuation.resume(returning: -1) }.connectLoopback { continuation.resume(returning: $0) }
        }
    }
}
