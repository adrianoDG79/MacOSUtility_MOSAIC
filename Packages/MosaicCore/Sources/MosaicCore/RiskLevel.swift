/// Risk classes of the Safety Engine (MOS-ARCH-001 §5.1). Every command and
/// every operation step declares one; a plan takes the highest of its steps.
public enum RiskLevel: Int, Sendable, Codable, CaseIterable, Comparable, CustomStringConvertible {
    /// R0: scans, analyses, previews. No approval.
    case none = 0
    /// R1: low and reversible, such as tagging a file or switching keyboard layout.
    case low
    /// R2: medium and reversible, such as bulk moves or moving files to the Trash.
    case medium
    /// R3: high, such as touching cloud-synced files or changing system settings.
    case high
    /// R4: irreversible. Never automatic.
    case irreversible

    public var code: String {
        "R\(rawValue)"
    }

    public var description: String {
        code
    }

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
