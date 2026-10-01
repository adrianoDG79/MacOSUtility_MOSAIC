/// Kind of an entity that search, relations, projects and the audit log can point to.
public struct EntityKind: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
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

    public static let file: EntityKind = "file"
    public static let folder: EntityKind = "folder"
    public static let mailMessage: EntityKind = "mail_message"
    public static let mailAttachment: EntityKind = "mail_attachment"
    public static let app: EntityKind = "app"
    public static let contact: EntityKind = "contact"
    public static let event: EntityKind = "event"
    public static let reminder: EntityKind = "reminder"
    public static let note: EntityKind = "note"
    public static let clipboardItem: EntityKind = "clipboard_item"
    public static let project: EntityKind = "project"
    public static let session: EntityKind = "session"
    public static let activityEvent: EntityKind = "activity_event"
    public static let command: EntityKind = "command"
}

/// Reference to any Mosaic entity, as stored by relations, projects and audit events (MOS-DM-001 §1).
public struct EntityRef: Hashable, Sendable, Codable, CustomStringConvertible {
    public let kind: EntityKind
    public let id: MosaicID

    public init(kind: EntityKind, id: MosaicID) {
        self.kind = kind
        self.id = id
    }

    public var description: String {
        "\(kind):\(id)"
    }
}
