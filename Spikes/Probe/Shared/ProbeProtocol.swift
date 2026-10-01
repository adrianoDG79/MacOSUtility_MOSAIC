import Foundation

/// Interface of the two probe XPC services (spike S2). The same calls run in an
/// unsandboxed service and in a sandboxed one, so their results can be compared.
@objc protocol ProbeServiceProtocol {
    /// Lists a directory; replies with the entry count and errno (0 on success).
    func listDirectory(_ path: String, reply: @escaping (Int, Int32) -> Void)
    /// Opens a path directly; replies with errno (0 on success).
    func openPath(_ path: String, reply: @escaping (Int32) -> Void)
    /// Reads from a descriptor opened by the app; replies with bytes read and errno.
    func read(_ handle: FileHandle, reply: @escaping (Int, Int32) -> Void)
    /// Tries a TCP connection to 127.0.0.1:43127; replies with errno (0 on success).
    func connectLoopback(reply: @escaping (Int32) -> Void)
    /// Describes the service process: pid and whether it runs in a sandbox.
    func describe(reply: @escaping (String) -> Void)
}

/// POSIX helpers shared by the app and the services.
enum ProbeIO {
    static func listDirectory(_ path: String) -> (Int, Int32) {
        guard let directory = opendir(path) else { return (0, errno) }
        defer { closedir(directory) }
        var count = 0
        while readdir(directory) != nil { count += 1 }
        return (count, 0)
    }

    static func openPath(_ path: String) -> Int32 {
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return errno }
        close(descriptor)
        return 0
    }

    static func read(descriptor: Int32) -> (Int, Int32) {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        return count < 0 ? (0, errno) : (count, 0)
    }

    static func connectLoopback(port: UInt16 = 43_127) -> Int32 {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return errno }
        defer { close(socketDescriptor) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0 ? 0 : errno
    }

    /// Makes reads of cloud-only files fail with EDEADLK instead of downloading them.
    static func disableDatalessMaterialization() {
        _ = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
    }

    static func describeError(_ code: Int32) -> String {
        code == 0 ? "ok" : "\(String(cString: strerror(code))) (\(code))"
    }
}
