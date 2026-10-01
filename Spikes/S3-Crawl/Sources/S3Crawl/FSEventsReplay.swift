import CoreServices
import Foundation
import os

/// Collects FSEvents delivered on a background queue.
final class EventCollector: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<(paths: [String: FSEventStreamEventFlags], historyDone: Bool, mustScan: Int)>(
        initialState: ([:], false, 0)
    )

    func add(path: String, flags: FSEventStreamEventFlags) {
        lock.withLock { state in
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) != 0 {
                state.historyDone = true
                return
            }
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 {
                state.mustScan += 1
            }
            state.paths[path, default: 0] |= flags
        }
    }

    var snapshot: (paths: [String: FSEventStreamEventFlags], historyDone: Bool, mustScan: Int) {
        lock.withLock { $0 }
    }
}

/// Simulates "Mosaic was quit, files changed, Mosaic relaunched": records the
/// current event ID, changes files with no stream running, then replays the
/// history since that ID and checks that every change is reported.
func runFSEventsReplay(in root: URL) throws -> [String: Any] {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let savedEventID = FSEventsGetCurrentEventId()

    // Changes made while no stream is running.
    let created = (0..<2_000).map { root.appending(path: "nuovo-\($0).txt") }
    for url in created { try Data("x".utf8).write(to: url) }
    for url in created.prefix(200) { try Data("modificato".utf8).write(to: url) }
    var renamedTargets: [URL] = []
    for url in created[200..<300] {
        let target = url.deletingLastPathComponent().appending(path: "rinominato-\(url.lastPathComponent)")
        try FileManager.default.moveItem(at: url, to: target)
        renamedTargets.append(target)
    }
    for url in created[300..<400] { try FileManager.default.removeItem(at: url) }
    let subfolder = root.appending(path: "sottocartella")
    try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
    let nested = (0..<50).map { subfolder.appending(path: "annidato-\($0).md") }
    for url in nested { try Data("y".utf8).write(to: url) }

    Thread.sleep(forTimeInterval: 2)

    let collector = EventCollector()
    var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(collector).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
    let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        let collector = Unmanaged<EventCollector>.fromOpaque(info!).takeUnretainedValue()
        let array = unsafeBitCast(paths, to: NSArray.self)
        for index in 0..<count {
            collector.add(path: array[index] as! String, flags: flags[index])
        }
    }
    let streamFlags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
    guard let stream = FSEventStreamCreate(nil, callback, &context, [root.path] as CFArray, savedEventID, 0.2, streamFlags) else {
        throw CocoaError(.featureUnsupported)
    }
    let queue = DispatchQueue(label: "s3.fsevents")
    FSEventStreamSetDispatchQueue(stream, queue)
    let start = ContinuousClock.now
    FSEventStreamStart(stream)
    while !collector.snapshot.historyDone && ContinuousClock.now - start < .seconds(20) {
        Thread.sleep(forTimeInterval: 0.02)
    }
    let replayDuration = ContinuousClock.now - start
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)

    let result = collector.snapshot
    // FSEvents reports canonical paths (/private/tmp rather than /tmp).
    func reported(_ url: URL) -> FSEventStreamEventFlags? {
        result.paths[url.resolvingSymlinksInPath().path] ?? result.paths[url.path]
    }
    let has = { (url: URL, flag: Int) in (reported(url) ?? 0) & FSEventStreamEventFlags(flag) != 0 }
    let createdSeen = created.filter { reported($0) != nil }.count
    let modifiedSeen = created.prefix(200).filter { has($0, kFSEventStreamEventFlagItemModified) }.count
    let renamedSeen = renamedTargets.filter { has($0, kFSEventStreamEventFlagItemRenamed) }.count
    let removedSeen = created[300..<400].filter { has($0, kFSEventStreamEventFlagItemRemoved) }.count
    let nestedSeen = nested.filter { reported($0) != nil }.count

    return [
        "history_done": result.historyDone,
        "replay_ms": Double(replayDuration.components.attoseconds) / 1e15 + Double(replayDuration.components.seconds) * 1_000,
        "created_reported": "\(createdSeen)/2000",
        "modified_reported": "\(modifiedSeen)/200",
        "renamed_reported": "\(renamedSeen)/100",
        "removed_reported": "\(removedSeen)/100",
        "nested_reported": "\(nestedSeen)/50",
        "must_scan_subdirs_events": result.mustScan,
        "distinct_paths": result.paths.count,
    ]
}
