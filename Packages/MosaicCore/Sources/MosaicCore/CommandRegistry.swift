import Foundation

/// Identifier of a registered command, for example `index.reindexSource`.
public struct CommandID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String {
        rawValue
    }
}

/// Categories of data a command reads or changes. The AI policy engine uses
/// them to decide whether a command may run on behalf of a cloud model.
public enum DataCategory: String, Sendable, Codable, CaseIterable {
    case fileMetadata
    case fileContent
    case mail
    case clipboard
    case activity
    case systemState
    case configuration
}

/// A typed parameter. The same description drives the Command Palette and,
/// from M3, the tool schema offered to AI models (ADR-015).
public struct CommandParameter: Sendable, Codable, Equatable {
    public enum ValueType: String, Sendable, Codable {
        case string
        case integer
        case number
        case boolean
        case date
        case entity
        case path
    }

    public let name: String
    public let type: ValueType
    public let summary: String
    public let isRequired: Bool
    /// Accepted values for string parameters; `nil` accepts any string.
    public let allowedValues: [String]?

    public init(name: String, type: ValueType, summary: String, isRequired: Bool = true, allowedValues: [String]? = nil) {
        self.name = name
        self.type = type
        self.summary = summary
        self.isRequired = isRequired
        self.allowedValues = allowedValues
    }
}

public enum CommandValue: Sendable, Equatable, Codable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case date(Date)
    case entity(EntityRef)
    case path(String)

    public var type: CommandParameter.ValueType {
        switch self {
        case .string: .string
        case .integer: .integer
        case .number: .number
        case .boolean: .boolean
        case .date: .date
        case .entity: .entity
        case .path: .path
        }
    }
}

public struct CommandArguments: Sendable, Equatable {
    public var values: [String: CommandValue]

    public init(_ values: [String: CommandValue] = [:]) {
        self.values = values
    }

    public subscript(name: String) -> CommandValue? {
        values[name]
    }
}

/// Everything a front end (UI, palette, menu bar, natural language, AI) needs
/// to know about a command before invoking it.
public struct CommandDescriptor: Sendable {
    public let id: CommandID
    public let title: String
    /// One or two sentences for the palette and for AI tool descriptions.
    public let summary: String
    public let keywords: [String]
    public let parameters: [CommandParameter]
    public let risk: RiskLevel
    public let requiredPermissions: Set<PermissionID>
    public let dataCategories: Set<DataCategory>
    /// Commands that change files or settings must produce an operation plan
    /// for the Safety Engine instead of acting directly (ADR-010).
    public let mutatesState: Bool

    public init(
        id: CommandID,
        title: String,
        summary: String,
        keywords: [String] = [],
        parameters: [CommandParameter] = [],
        risk: RiskLevel = .none,
        requiredPermissions: Set<PermissionID> = [],
        dataCategories: Set<DataCategory> = [],
        mutatesState: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.keywords = keywords
        self.parameters = parameters
        self.risk = risk
        self.requiredPermissions = requiredPermissions
        self.dataCategories = dataCategories
        self.mutatesState = mutatesState
    }
}

public enum CommandOutcome: Sendable, Equatable {
    case completed(message: String)
    /// The command produced a plan that now waits for approval in the Safety Engine.
    case operationPlanned(MosaicID)
}

/// Checks run before every invocation. M1 plugs in the permission gate and
/// the Safety Engine here without changing the registry.
public protocol CommandInvocationGuard: Sendable {
    func authorize(_ descriptor: CommandDescriptor, _ arguments: CommandArguments) async throws
}

public typealias CommandHandler = @Sendable (CommandArguments) async throws -> CommandOutcome

/// The single registry of user-invokable actions (MOS-ARCH-001 §4.5).
public actor CommandRegistry {
    private struct Entry {
        let descriptor: CommandDescriptor
        let handler: CommandHandler
    }

    private var entries: [CommandID: Entry] = [:]
    private let guards: [any CommandInvocationGuard]

    public init(guards: [any CommandInvocationGuard] = []) {
        self.guards = guards
    }

    public func register(_ descriptor: CommandDescriptor, handler: @escaping CommandHandler) throws {
        guard entries[descriptor.id] == nil else {
            throw MosaicError.duplicate("Il comando \(descriptor.id) è già registrato.")
        }
        entries[descriptor.id] = Entry(descriptor: descriptor, handler: handler)
    }

    public func unregister(_ id: CommandID) {
        entries[id] = nil
    }

    public func descriptor(for id: CommandID) -> CommandDescriptor? {
        entries[id]?.descriptor
    }

    public var descriptors: [CommandDescriptor] {
        entries.values.map(\.descriptor).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func invoke(_ id: CommandID, arguments: CommandArguments = CommandArguments()) async throws -> CommandOutcome {
        guard let entry = entries[id] else {
            throw MosaicError.notFound("Comando sconosciuto: \(id).")
        }
        try Self.validate(arguments, against: entry.descriptor.parameters, command: id)
        for invocationGuard in guards {
            try await invocationGuard.authorize(entry.descriptor, arguments)
        }
        return try await entry.handler(arguments)
    }

    static func validate(_ arguments: CommandArguments, against parameters: [CommandParameter], command: CommandID) throws {
        let known = Set(parameters.map(\.name))
        if let unknown = arguments.values.keys.sorted().first(where: { !known.contains($0) }) {
            throw MosaicError.invalidArgument("Il comando \(command) non ha un parametro \"\(unknown)\".")
        }
        for parameter in parameters {
            guard let value = arguments[parameter.name] else {
                if parameter.isRequired {
                    throw MosaicError.invalidArgument("Il comando \(command) richiede il parametro \"\(parameter.name)\".")
                }
                continue
            }
            guard value.type == parameter.type else {
                throw MosaicError.invalidArgument("Il parametro \"\(parameter.name)\" deve essere di tipo \(parameter.type.rawValue).")
            }
            if let allowed = parameter.allowedValues, case .string(let string) = value, !allowed.contains(string) {
                throw MosaicError.invalidArgument("Valore non ammesso per \"\(parameter.name)\": \(string).")
            }
        }
    }
}
