import Foundation
import MosaicCore
import MosaicPlatform
import MosaicStorage
import Observation
import ServiceManagement

/// Services wired together at launch. Explicit composition keeps dependencies
/// visible; modules receive what they need instead of looking it up.
struct AppServices: Sendable {
    let coreStore: MosaicStore
    let device: DeviceRecord
    let events: EventBus
    let commands: CommandRegistry
    let jobs: JobScheduler

    static func bootstrap() throws -> AppServices {
        let secrets = KeychainSecretsStore(service: MosaicLog.subsystem)
        let core = try MosaicStore.open(
            .core,
            in: try StoreLocation.applicationSupport(),
            keyProvider: KeychainDatabaseKeyProvider(secrets: secrets),
            migrator: CoreSchema.migrator
        )
        return AppServices(
            coreStore: core,
            device: try DeviceRegistry.currentDevice(in: core),
            events: EventBus(),
            commands: CommandRegistry(),
            jobs: JobScheduler()
        )
    }

    func shutdown() async {
        await jobs.shutdown()
        try? coreStore.close()
    }
}

/// Facts about the M0 foundations, shown in the main window. Everything here
/// is read from the running system; nothing is a placeholder.
struct FoundationStatus: Sendable {
    let engine: EngineInfo
    let databasePath: String
    let device: DeviceRecord
    let jobs: JobSnapshot
}

@MainActor
@Observable
final class AppModel {
    enum State {
        case starting
        case ready(FoundationStatus)
        case failed(String)
    }

    private(set) var state: State = .starting
    private(set) var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    private(set) var loginItemError: String?
    private var services: AppServices?
    private let logger = MosaicLog.logger(category: "app")

    func start() async {
        do {
            let services = try AppServices.bootstrap()
            self.services = services
            state = .ready(try await status(of: services))
        } catch {
            logger.error("Bootstrap failed: \(String(describing: error), privacy: .public)")
            state = .failed(String(describing: error))
        }
    }

    func refresh() async {
        guard let services else { return }
        if let status = try? await status(of: services) {
            state = .ready(status)
        }
        loginItemStatus = SMAppService.mainApp.status
    }

    /// Optional launch at login (D2). macOS may ask the user to approve it.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemStatus = SMAppService.mainApp.status
    }

    func shutdown() async {
        await services?.shutdown()
        services = nil
    }

    private func status(of services: AppServices) async throws -> FoundationStatus {
        FoundationStatus(
            engine: try services.coreStore.engineInfo(),
            databasePath: services.coreStore.url.path,
            device: services.device,
            jobs: await services.jobs.snapshot
        )
    }
}
