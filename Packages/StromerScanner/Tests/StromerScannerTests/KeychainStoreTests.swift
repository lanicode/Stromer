import Foundation
@testable import StromerScanner
import XCTest

final class KeychainStoreTests: XCTestCase {
    func testSaveLoadDeleteViaMockStore() throws {
        let store = InMemoryKeychainStore()
        let account = "device-1"
        let key = Data([0xAF, 0xF4])

        try store.saveKey(key, for: account)
        XCTAssertEqual(try store.loadKey(for: account), key)

        try store.deleteKey(for: account)
        XCTAssertNil(try store.loadKey(for: account))
    }
}

private final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func saveKey(_ key: Data, for account: String) throws {
        storage[account] = key
    }

    func loadKey(for account: String) throws -> Data? {
        storage[account]
    }

    func deleteKey(for account: String) throws {
        storage.removeValue(forKey: account)
    }
}
