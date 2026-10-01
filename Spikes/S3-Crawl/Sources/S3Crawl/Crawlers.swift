import Darwin
import Foundation

/// Aggregate counts only: the spike never records file names or paths.
struct CrawlStats: Sendable {
    var files = 0
    var directories = 0
    var symlinks = 0
    var other = 0
    var bytes: Int64 = 0
    var datalessFiles = 0
    var skippedDirectories = 0
    var errors: [String: Int] = [:]

    mutating func recordError(_ code: Int32) {
        errors[String(cString: strerror(code)), default: 0] += 1
    }

    var json: [String: Any] {
        ["files": files, "directories": directories, "symlinks": symlinks, "other": other, "bytes": bytes,
         "dataless_files": datalessFiles, "skipped_directories": skippedDirectories, "errors": errors]
    }
}

/// Mosaic's default exclusions (MOS-SRCH-001 §3) and common package extensions,
/// whose contents are one item for Mosaic.
struct CrawlRules: Sendable {
    let excludedNames: Set<String> = ["node_modules", ".git", ".build", "DerivedData", ".svn", "__pycache__", ".venv", ".Trash"]
    let excludedPaths: Set<String>
    let packageExtensions: Set<String> = ["app", "bundle", "framework", "photoslibrary", "xcodeproj", "xcworkspace", "playground",
                                          "rtfd", "pages", "numbers", "key", "logicx", "fcpbundle", "band", "musiclibrary",
                                          "photolibrary", "xcarchive", "plugin", "kext", "appex", "xpc"]

    func shouldSkip(directoryNamed name: String, at path: String) -> Bool {
        if excludedNames.contains(name) || excludedPaths.contains(path) { return true }
        guard let dot = name.lastIndex(of: ".") else { return false }
        return packageExtensions.contains(name[name.index(after: dot)...].lowercased())
    }
}

/// Tells the kernel not to download cloud (dataless) files for this process:
/// reads of such files fail with EDEADLK instead (D8, MOS-MAC-001 §2).
func disableDatalessMaterialization() -> Bool {
    setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF) == 0
}

// MARK: - getattrlistbulk

private let attrCmnReturnedAttrs: attrgroup_t = 0x8000_0000
private let attrCmnName: attrgroup_t = 0x0000_0001
private let attrCmnObjType: attrgroup_t = 0x0000_0008
private let attrCmnModTime: attrgroup_t = 0x0000_0400
private let attrCmnFlags: attrgroup_t = 0x0004_0000
private let attrCmnFileID: attrgroup_t = 0x0200_0000
private let attrFileTotalSize: attrgroup_t = 0x0000_0002
private let fsoptPackInvalAttrs: UInt64 = 0x0000_0008
private let sfDataless: UInt32 = 0x4000_0000
private let vREG: UInt32 = 1
private let vDIR: UInt32 = 2
private let vLNK: UInt32 = 5

/// Walks `root` with getattrlistbulk: one system call returns the metadata of
/// many directory entries at once.
func crawlWithBulkAttributes(root: String, rules: CrawlRules) -> CrawlStats {
    var stats = CrawlStats()
    var request = attrlist()
    request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
    request.commonattr = attrCmnReturnedAttrs | attrCmnName | attrCmnObjType | attrCmnModTime | attrCmnFlags | attrCmnFileID
    request.fileattr = attrFileTotalSize
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 256 * 1024, alignment: 8)
    defer { buffer.deallocate() }

    var stack = [root]
    while let directory = stack.popLast() {
        let descriptor = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            stats.recordError(errno)
            continue
        }
        defer { close(descriptor) }
        while true {
            let count = getattrlistbulk(descriptor, &request, buffer.baseAddress!, buffer.count, fsoptPackInvalAttrs)
            if count < 0 {
                stats.recordError(errno)
                break
            }
            if count == 0 { break }
            var entry = buffer.baseAddress!
            for _ in 0..<count {
                let length = entry.loadUnaligned(as: UInt32.self)
                var cursor = entry + 4 + MemoryLayout<attribute_set_t>.size
                let nameReference = cursor
                let nameOffset = cursor.loadUnaligned(as: Int32.self)
                cursor += 8
                let type = cursor.loadUnaligned(as: UInt32.self)
                cursor += 4 + MemoryLayout<timespec>.size
                let flags = cursor.loadUnaligned(as: UInt32.self)
                cursor += 4 + 8 // flags, file ID
                let size = cursor.loadUnaligned(as: Int64.self)
                let name = String(cString: (nameReference + Int(nameOffset)).assumingMemoryBound(to: CChar.self))

                switch type {
                case vDIR:
                    stats.directories += 1
                    let path = directory + "/" + name
                    if rules.shouldSkip(directoryNamed: name, at: path) {
                        stats.skippedDirectories += 1
                    } else {
                        stack.append(path)
                    }
                case vREG:
                    stats.files += 1
                    stats.bytes += size
                    if flags & sfDataless != 0 { stats.datalessFiles += 1 }
                case vLNK:
                    stats.symlinks += 1
                default:
                    stats.other += 1
                }
                entry += Int(length)
            }
        }
    }
    return stats
}

// MARK: - FileManager

/// Walks `root` with FileManager's enumerator and prefetched resource values.
func crawlWithFileManager(root: String, rules: CrawlRules) -> CrawlStats {
    var stats = CrawlStats()
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey,
                                  .contentModificationDateKey, .fileResourceIdentifierKey]
    var errorCodes: [Int32] = []
    let enumerator = FileManager.default.enumerator(
        at: URL(filePath: root, directoryHint: .isDirectory),
        includingPropertiesForKeys: keys,
        options: [],
        errorHandler: { _, error in
            errorCodes.append(Int32((error as NSError).code))
            return true
        }
    )
    while let url = enumerator?.nextObject() as? URL {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
            stats.other += 1
            continue
        }
        if values.isSymbolicLink == true {
            stats.symlinks += 1
        } else if values.isDirectory == true {
            stats.directories += 1
            if rules.shouldSkip(directoryNamed: url.lastPathComponent, at: url.path) {
                stats.skippedDirectories += 1
                enumerator?.skipDescendants()
            }
        } else if values.isRegularFile == true {
            stats.files += 1
            stats.bytes += Int64(values.fileSize ?? 0)
        } else {
            stats.other += 1
        }
    }
    stats.errors["enumeration errors"] = errorCodes.count
    return stats
}

// MARK: - Synthetic tree

/// Creates `directories × subdirectories × filesPerDirectory` empty files.
func makeSyntheticTree(at root: URL, directories: Int, subdirectories: Int, filesPerDirectory: Int) throws -> Int {
    var created = 0
    for top in 0..<directories {
        for sub in 0..<subdirectories {
            let directory = root.appending(path: "progetto-\(top)/cartella-\(sub)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for index in 0..<filesPerDirectory {
                let path = directory.appending(path: "Documento_\(index)_v\(index % 7).pdf").path
                let descriptor = open(path, O_CREAT | O_WRONLY, 0o644)
                if descriptor >= 0 {
                    close(descriptor)
                    created += 1
                }
            }
        }
    }
    return created
}
