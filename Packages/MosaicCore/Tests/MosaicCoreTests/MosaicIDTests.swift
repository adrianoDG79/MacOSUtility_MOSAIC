import Foundation
import Testing
@testable import MosaicCore

struct MosaicIDTests {
    @Test func setsVersionAndVariantBits() {
        for _ in 0..<1_000 {
            let id = MosaicID.generate()
            #expect(id.version == 7)
            #expect(id.bytes[8] & 0xC0 == 0x80)
        }
    }

    @Test func encodesCreationTimeWithMillisecondPrecision() {
        let date = Date(timeIntervalSince1970: 1_790_000_000.123)
        let id = MosaicID.generate(at: date)
        #expect(abs(id.timestamp.timeIntervalSince(date)) < 0.001)
    }

    @Test func ordersByCreationTimeAcrossMilliseconds() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let ids = (0..<500).map { MosaicID.generate(at: start.addingTimeInterval(Double($0) / 1_000)) }
        #expect(ids.sorted() == ids)
    }

    @Test func doesNotRepeat() {
        let ids = Set((0..<20_000).map { _ in MosaicID.generate() })
        #expect(ids.count == 20_000)
    }

    @Test func roundTripsThroughDataStringAndJSON() throws {
        let id = MosaicID.generate()
        #expect(MosaicID(data: id.data) == id)
        #expect(MosaicID(string: id.description) == id)
        let decoded = try JSONDecoder().decode(MosaicID.self, from: JSONEncoder().encode(id))
        #expect(decoded == id)
        #expect(id.description == id.description.lowercased())
    }

    @Test func rejectsDataOfTheWrongSize() {
        #expect(MosaicID(data: Data(repeating: 0, count: 15)) == nil)
        #expect(MosaicID(data: Data(repeating: 0, count: 17)) == nil)
    }
}
