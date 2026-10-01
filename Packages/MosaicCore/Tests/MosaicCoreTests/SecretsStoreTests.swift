import Foundation
import Testing
@testable import MosaicCore

struct SecretsStoreTests {
    @Test func inMemoryStoreRoundTrips() throws {
        let store = InMemorySecretsStore()
        #expect(try store.data(for: "key") == nil)
        try store.set(Data([1, 2, 3]), for: "key")
        #expect(try store.data(for: "key") == Data([1, 2, 3]))
        try store.remove("key")
        #expect(try store.data(for: "key") == nil)
    }

    /// Writes a temporary item to the login keychain, so it runs only on request:
    /// `MOSAIC_KEYCHAIN_TESTS=1 swift test`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MOSAIC_KEYCHAIN_TESTS"] == "1"))
    func keychainStoreRoundTripsAndCleansUp() throws {
        let store = KeychainSecretsStore(service: "it.mosaic.app.tests")
        let account = "roundtrip-\(MosaicID.generate())"
        defer { try? store.remove(account) }

        #expect(try store.data(for: account) == nil)
        try store.set(Data("first".utf8), for: account)
        try store.set(Data("second".utf8), for: account)
        #expect(try store.data(for: account) == Data("second".utf8))
        try store.remove(account)
        #expect(try store.data(for: account) == nil)
    }
}
