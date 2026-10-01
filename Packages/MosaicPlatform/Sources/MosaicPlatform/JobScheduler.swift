import MosaicCore

/// Priority classes of MOS-ARCH-001 §6.1.
public enum JobPriority: Int, Sendable, CaseIterable, Comparable, CustomStringConvertible {
    /// P0: search queries, previews. Never queued behind other work.
    case interactive = 0
    /// P1: work the user just asked for, such as "reindex now".
    case userInitiated
    /// P2: incremental maintenance, such as FSEvents updates.
    case maintenance
    /// P3: bulk work such as the first crawl, OCR and embeddings.
    /// On Apple Silicon, background priority runs on the efficiency cores.
    case bulk

    public var taskPriority: TaskPriority {
        switch self {
        case .interactive: .high
        case .userInitiated: .medium
        case .maintenance: .utility
        case .bulk: .background
        }
    }

    public var description: String {
        "P\(rawValue)"
    }

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct JobLimits: Sendable {
    public var maxConcurrent: [JobPriority: Int]

    public init(maxConcurrent: [JobPriority: Int]) {
        self.maxConcurrent = maxConcurrent
    }

    public static let standard = JobLimits(maxConcurrent: [.interactive: 4, .userInitiated: 2, .maintenance: 2, .bulk: 1])
}

public struct JobSnapshot: Sendable, Equatable {
    public let queued: [JobPriority: Int]
    public let running: [JobPriority: Int]
    public let paused: Set<JobPriority>
    public let isShutDown: Bool

    public var isIdle: Bool {
        queued.values.allSatisfy { $0 == 0 } && running.values.allSatisfy { $0 == 0 }
    }
}

/// Runs background work in four priority lanes with per-lane concurrency limits.
///
/// Lanes can be paused and resumed (the Resource Manager will drive this from
/// M3). `shutdown()` stops everything, which is what quitting Mosaic does (D2).
public actor JobScheduler {
    public typealias Operation = @Sendable () async throws -> Void

    private struct PendingJob: Sendable {
        let id: MosaicID
        let name: String
        let operation: Operation
    }

    private struct RunningJob {
        let priority: JobPriority
        let task: Task<Void, Never>
    }

    private let limits: JobLimits
    private var queues: [JobPriority: [PendingJob]] = [:]
    private var running: [MosaicID: RunningJob] = [:]
    private var paused: Set<JobPriority> = []
    private var isShutDown = false
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    private let logger = MosaicLog.logger(category: "jobs")

    public init(limits: JobLimits = .standard) {
        self.limits = limits
    }

    @discardableResult
    public func submit(_ priority: JobPriority, name: String, operation: @escaping Operation) throws -> MosaicID {
        guard !isShutDown else { throw MosaicError.cancelled }
        let job = PendingJob(id: .generate(), name: name, operation: operation)
        queues[priority, default: []].append(job)
        startEligibleJobs()
        return job.id
    }

    public func pause(_ priority: JobPriority) {
        paused.insert(priority)
        resumeIdleWaitersIfIdle()
    }

    public func resume(_ priority: JobPriority) {
        paused.remove(priority)
        startEligibleJobs()
    }

    /// Drops a queued job, or cancels it if it is already running.
    public func cancel(_ id: MosaicID) {
        for priority in JobPriority.allCases {
            queues[priority]?.removeAll { $0.id == id }
        }
        running[id]?.task.cancel()
        resumeIdleWaitersIfIdle()
    }

    /// Drops queued work, cancels running jobs and waits for them to finish.
    /// Afterwards the scheduler refuses new work.
    public func shutdown() async {
        isShutDown = true
        queues.removeAll()
        let tasks = running.values.map(\.task)
        for task in tasks {
            task.cancel()
        }
        for task in tasks {
            await task.value
        }
        resumeIdleWaitersIfIdle()
    }

    /// Returns once nothing is running and no job is waiting in an active lane.
    public func waitUntilIdle() async {
        guard !isIdleIgnoringPausedLanes else { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    public var snapshot: JobSnapshot {
        var queued: [JobPriority: Int] = [:]
        var active: [JobPriority: Int] = [:]
        for priority in JobPriority.allCases {
            queued[priority] = queues[priority]?.count ?? 0
            active[priority] = running.values.filter { $0.priority == priority }.count
        }
        return JobSnapshot(queued: queued, running: active, paused: paused, isShutDown: isShutDown)
    }

    private var isIdleIgnoringPausedLanes: Bool {
        running.isEmpty && JobPriority.allCases.allSatisfy { paused.contains($0) || (queues[$0]?.isEmpty ?? true) }
    }

    private func startEligibleJobs() {
        guard !isShutDown else { return }
        for priority in JobPriority.allCases where !paused.contains(priority) {
            let limit = limits.maxConcurrent[priority] ?? 1
            while running.values.filter({ $0.priority == priority }).count < limit,
                  let job = queues[priority]?.first {
                queues[priority]?.removeFirst()
                start(job, priority: priority)
            }
        }
    }

    private func start(_ job: PendingJob, priority: JobPriority) {
        // The task cannot report completion before it is recorded: `finished`
        // runs on this actor, which is busy until `start` returns.
        let task = Task(priority: priority.taskPriority) { [weak self] in
            var failure: String?
            do {
                try await job.operation()
            } catch is CancellationError {
                // Cancellation is an expected outcome, not a failure.
            } catch {
                failure = String(describing: error)
            }
            await self?.finished(job.id, name: job.name, failure: failure)
        }
        running[job.id] = RunningJob(priority: priority, task: task)
    }

    private func finished(_ id: MosaicID, name: String, failure: String?) {
        running[id] = nil
        if let failure {
            logger.error("Job \(name, privacy: .public) failed: \(failure, privacy: .private)")
        }
        startEligibleJobs()
        resumeIdleWaitersIfIdle()
    }

    private func resumeIdleWaitersIfIdle() {
        guard isIdleIgnoringPausedLanes else { return }
        let waiters = idleWaiters
        idleWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
