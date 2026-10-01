import Foundation

/// Stable, globally unique identifier for every Mosaic entity (ADR-013).
///
/// Values are UUIDv7 (RFC 9562): the first 48 bits hold the creation time in
/// Unix milliseconds, so byte order follows creation order across milliseconds.
/// That keeps identifiers meaningful if data is ever merged across Macs (§57).
public struct MosaicID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let uuid: UUID

    public init(uuid: UUID) {
        self.uuid = uuid
    }

    public init?(string: String) {
        guard let uuid = UUID(uuidString: string) else { return nil }
        self.uuid = uuid
    }

    public init?(data: Data) {
        guard data.count == 16 else { return nil }
        uuid = data.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
    }

    /// A new identifier stamped with `date`.
    public static func generate(at date: Date = Date()) -> MosaicID {
        var generator = SystemRandomNumberGenerator()
        return generate(at: date, using: &generator)
    }

    public static func generate<Generator: RandomNumberGenerator>(at date: Date, using generator: inout Generator) -> MosaicID {
        // Nearest, not truncated: a date meant to fall on an exact millisecond is
        // often stored a hair below it, and truncation would land on the previous one.
        let milliseconds = UInt64(max(0, (date.timeIntervalSince1970 * 1_000).rounded()))
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: milliseconds >> (8 * (5 - index)))
        }
        let high = generator.next()
        let low = generator.next()
        for index in 0..<8 {
            bytes[6 + index] = UInt8(truncatingIfNeeded: high >> (8 * index))
        }
        bytes[14] = UInt8(truncatingIfNeeded: low)
        bytes[15] = UInt8(truncatingIfNeeded: low >> 8)
        bytes[6] = 0x70 | (bytes[6] & 0x0F) // version 7
        bytes[8] = 0x80 | (bytes[8] & 0x3F) // RFC 9562 variant
        return MosaicID(data: Data(bytes))!
    }

    public var bytes: [UInt8] {
        withUnsafeBytes(of: uuid.uuid) { Array($0) }
    }

    public var data: Data {
        Data(bytes)
    }

    public var version: Int {
        Int(bytes[6] >> 4)
    }

    /// Creation time encoded in the identifier, with millisecond precision.
    public var timestamp: Date {
        let milliseconds = bytes.prefix(6).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    public var description: String {
        uuid.uuidString.lowercased()
    }

    public static func < (lhs: MosaicID, rhs: MosaicID) -> Bool {
        lhs.bytes.lexicographicallyPrecedes(rhs.bytes)
    }
}

extension MosaicID: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let id = MosaicID(string: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a UUID: \(string)")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
