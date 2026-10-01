/// Errors classified by cause, so Diagnostics can explain why something failed
/// instead of reporting a generic failure (§54, MOS-ARCH-001 §7).
///
/// Messages are user-facing and in Italian; they never contain document content.
public enum MosaicError: Error, Sendable, Equatable, CustomStringConvertible {
    case permissionRequired(PermissionID)
    case sourceUnavailable(String)
    case externalClient(name: String, reason: String)
    case invalidFormat(String)
    case resourceLimit(String)
    case notFound(String)
    case invalidArgument(String)
    case duplicate(String)
    case cancelled
    case internalFailure(String)

    public enum Category: String, Sendable {
        case permission
        case source
        case externalClient
        case format
        case resource
        case input
        case cancellation
        case internalFailure
    }

    public var category: Category {
        switch self {
        case .permissionRequired: .permission
        case .sourceUnavailable: .source
        case .externalClient: .externalClient
        case .invalidFormat: .format
        case .resourceLimit: .resource
        case .notFound, .invalidArgument, .duplicate: .input
        case .cancelled: .cancellation
        case .internalFailure: .internalFailure
        }
    }

    public var description: String {
        switch self {
        case .permissionRequired(let permission): "Serve il permesso \(permission.displayName)."
        case .sourceUnavailable(let detail): "Sorgente non disponibile: \(detail)"
        case .externalClient(let name, let reason): "\(name) non risponde come previsto: \(reason)"
        case .invalidFormat(let detail): detail
        case .resourceLimit(let detail): "Limite di risorse raggiunto: \(detail)"
        case .notFound(let detail): detail
        case .invalidArgument(let detail): detail
        case .duplicate(let detail): detail
        case .cancelled: "Operazione annullata."
        case .internalFailure(let detail): "Errore interno: \(detail)"
        }
    }
}
