import MosaicCore
import Testing
@testable import MosaicPlatform

/// Tracks how many jobs run at the same time and which ones ran.
private actor Probe {
    private(set) var current = 0
    private(set) var peak = 0
    private(set) var completed: [String] = []

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave(_ name: String) {
        current -= 1
        completed.append(name)
    }
}

struct JobSchedulerTests {
    @Test(arguments: [(JobPriority.bulk, 1), (JobPriority.userInitiated, 2), (JobPriority.interactive, 4)])
    func respectsTheConcurrencyLimitOfEachLane(priority: JobPriority, limit: Int) async throws {
        let scheduler = JobScheduler()
        let probe = Probe()
        for index in 0..<(limit * 3) {
            try await scheduler.submit(priority, name: "job-\(index)") {
                await probe.enter()
                try await Task.sleep(for: .milliseconds(15))
                await probe.leave("job-\(index)")
            }
        }
        await scheduler.waitUntilIdle()
        #expect(await probe.peak == limit)
        #expect(await probe.completed.count == limit * 3)
    }

    @Test func pausedLanesStartNothingUntilResumed() async throws {
        let scheduler = JobScheduler()
        let probe = Probe()
        await scheduler.pause(.bulk)
        try await scheduler.submit(.bulk, name: "ocr") { await probe.enter(); await probe.leave("ocr") }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await probe.completed.isEmpty)
        #expect(await scheduler.snapshot.queued[.bulk] == 1)

        await scheduler.resume(.bulk)
        await scheduler.waitUntilIdle()
        #expect(await probe.completed == ["ocr"])
    }

    @Test func cancelledQueuedJobsNeverRun() async throws {
        let scheduler = JobScheduler()
        let probe = Probe()
        try await scheduler.submit(.bulk, name: "long") {
            try await Task.sleep(for: .milliseconds(80))
            await probe.enter(); await probe.leave("long")
        }
        let queued = try await scheduler.submit(.bulk, name: "queued") { await probe.enter(); await probe.leave("queued") }
        await scheduler.cancel(queued)
        await scheduler.waitUntilIdle()
        #expect(await probe.completed == ["long"])
    }

    @Test func shutdownCancelsRunningWorkAndRefusesNewJobs() async throws {
        let scheduler = JobScheduler()
        let probe = Probe()
        try await scheduler.submit(.maintenance, name: "watcher") {
            await probe.enter()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
            }
            await probe.leave("watcher")
        }
        try await waitUntil { await probe.current == 1 }

        await scheduler.shutdown()
        #expect(await probe.completed == ["watcher"])
        #expect(await scheduler.snapshot.isShutDown)
        await #expect(throws: MosaicError.cancelled) {
            try await scheduler.submit(.interactive, name: "late") {}
        }
    }

    @Test func aFailingJobDoesNotStopTheLane() async throws {
        let scheduler = JobScheduler()
        let probe = Probe()
        struct Failure: Error {}
        try await scheduler.submit(.bulk, name: "broken") { throw Failure() }
        try await scheduler.submit(.bulk, name: "next") { await probe.enter(); await probe.leave("next") }
        await scheduler.waitUntilIdle()
        #expect(await probe.completed == ["next"])
    }

    @Test func mapsLanesToDecreasingTaskPriorities() {
        let priorities = JobPriority.allCases.map(\.taskPriority.rawValue)
        #expect(priorities == priorities.sorted(by: >))
        #expect(JobPriority.bulk.taskPriority == .background)
    }
}

private func waitUntil(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition not met within two seconds")
}
