import Foundation
import Testing
@testable import MosaicCore

private let reindex = CommandDescriptor(
    id: "index.reindexSource",
    title: "Reindicizza sorgente",
    summary: "Rielabora una sorgente senza toccare le altre.",
    parameters: [
        CommandParameter(name: "source", type: .string, summary: "Nome della sorgente"),
        CommandParameter(name: "phase", type: .string, summary: "Fase da ripetere", isRequired: false,
                         allowedValues: ["metadata", "text", "ocr", "embeddings"]),
    ],
    dataCategories: [.fileMetadata, .fileContent]
)

/// Rejects every command that would change state, as M1's Safety Engine guard will.
private struct RejectMutations: CommandInvocationGuard {
    func authorize(_ descriptor: CommandDescriptor, _ arguments: CommandArguments) async throws {
        if descriptor.mutatesState {
            throw MosaicError.permissionRequired(.fullDiskAccess)
        }
    }
}

struct CommandRegistryTests {
    @Test func invokesARegisteredCommandWithValidArguments() async throws {
        let registry = CommandRegistry()
        try await registry.register(reindex) { arguments in
            guard case .string(let source) = arguments["source"] else { return .completed(message: "") }
            return .completed(message: "Reindex di \(source)")
        }
        let outcome = try await registry.invoke("index.reindexSource", arguments: CommandArguments(["source": .string("Download")]))
        #expect(outcome == .completed(message: "Reindex di Download"))
    }

    @Test func refusesDuplicateRegistrations() async throws {
        let registry = CommandRegistry()
        try await registry.register(reindex) { _ in .completed(message: "") }
        await #expect(throws: MosaicError.self) {
            try await registry.register(reindex) { _ in .completed(message: "") }
        }
    }

    @Test func rejectsUnknownCommandsAndInvalidArguments() async throws {
        let registry = CommandRegistry()
        try await registry.register(reindex) { _ in .completed(message: "") }

        await #expect(throws: MosaicError.self) { try await registry.invoke("index.unknown") }
        // Missing required parameter.
        await #expect(throws: MosaicError.self) { try await registry.invoke("index.reindexSource") }
        // Wrong type.
        await #expect(throws: MosaicError.self) {
            try await registry.invoke("index.reindexSource", arguments: CommandArguments(["source": .integer(3)]))
        }
        // Unknown parameter.
        await #expect(throws: MosaicError.self) {
            try await registry.invoke("index.reindexSource", arguments: CommandArguments(["source": .string("A"), "force": .boolean(true)]))
        }
        // Value outside the allowed list.
        await #expect(throws: MosaicError.self) {
            try await registry.invoke("index.reindexSource", arguments: CommandArguments(["source": .string("A"), "phase": .string("all")]))
        }
    }

    @Test func runsGuardsBeforeTheHandler() async throws {
        let registry = CommandRegistry(guards: [RejectMutations()])
        let move = CommandDescriptor(id: "files.move", title: "Sposta", summary: "Sposta file.", risk: .medium, mutatesState: true)
        let ran = HandlerFlag()
        try await registry.register(move) { _ in
            await ran.set()
            return .completed(message: "")
        }
        await #expect(throws: MosaicError.permissionRequired(.fullDiskAccess)) { try await registry.invoke("files.move") }
        #expect(await ran.value == false)
    }

    @Test func listsDescriptorsByTitle() async throws {
        let registry = CommandRegistry()
        for (id, title) in [("b", "Salute del Mac"), ("a", "Apri Mosaic"), ("c", "Reindicizza")] {
            try await registry.register(CommandDescriptor(id: CommandID(rawValue: id), title: title, summary: "")) { _ in .completed(message: "") }
        }
        #expect(await registry.descriptors.map(\.title) == ["Apri Mosaic", "Reindicizza", "Salute del Mac"])
    }
}

private actor HandlerFlag {
    private(set) var value = false
    func set() { value = true }
}
