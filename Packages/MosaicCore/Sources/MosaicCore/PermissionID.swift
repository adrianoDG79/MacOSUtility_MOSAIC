/// The permissions of the permission matrix (MOS-PERM-001), by their matrix code.
public enum PermissionID: String, Sendable, Codable, CaseIterable, CustomStringConvertible {
    case fullDiskAccess
    case protectedFolders
    case externalVolumes
    case cloudFileProviders
    case inputMonitoring
    case accessibility
    case automation
    case contacts
    case calendars
    case reminders
    case notifications
    case loginItem
    case localNetwork
    case locationServices
    case appManagement
    case pasteboard
    case administrator
    case keychain
    case appleIntelligence

    /// Code used in MOS-PERM-001, from P1 to P19.
    public var matrixCode: String {
        "P\(Self.allCases.firstIndex(of: self)! + 1)"
    }

    public var displayName: String {
        switch self {
        case .fullDiskAccess: "Accesso completo al disco"
        case .protectedFolders: "File e cartelle"
        case .externalVolumes: "Volumi rimovibili e di rete"
        case .cloudFileProviders: "File gestiti da provider cloud"
        case .inputMonitoring: "Monitoraggio dell'input"
        case .accessibility: "Accessibilità"
        case .automation: "Automazione"
        case .contacts: "Contatti"
        case .calendars: "Calendari"
        case .reminders: "Promemoria"
        case .notifications: "Notifiche"
        case .loginItem: "Elementi login"
        case .localNetwork: "Rete locale"
        case .locationServices: "Servizi di localizzazione"
        case .appManagement: "Gestione app"
        case .pasteboard: "Accesso agli appunti"
        case .administrator: "Autorizzazione di amministratore"
        case .keychain: "Portachiavi"
        case .appleIntelligence: "Apple Intelligence"
        }
    }

    public var description: String {
        matrixCode
    }
}
