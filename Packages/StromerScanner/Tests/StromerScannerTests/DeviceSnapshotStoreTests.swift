import Foundation
@testable import StromerScanner
import XCTest

final class DeviceSnapshotStoreTests: XCTestCase {
    func testCodableRoundtripThroughMockBackingStore() throws {
        let backing = DeviceSnapshotKeyValueStore()
        let store = AppGroupDeviceSnapshotStore(backing: backing)
        let snapshot = RegisteredDeviceSnapshot(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "SmartShunt",
            peripheralID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            localName: "SmartShunt HT",
            productID: 0xA389,
            recordType: 0x02,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastRSSI: -68
        )

        try store.saveDeviceSnapshots([snapshot])

        XCTAssertEqual(try store.loadDeviceSnapshots(), [snapshot])
    }

    func testDeletesSingleDeviceSnapshot() throws {
        let backing = DeviceSnapshotKeyValueStore()
        let store = AppGroupDeviceSnapshotStore(backing: backing)
        let first = RegisteredDeviceSnapshot(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "A"
        )
        let second = RegisteredDeviceSnapshot(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "B"
        )

        try store.saveDeviceSnapshots([first, second])
        try store.deleteDeviceSnapshot(id: first.id)

        XCTAssertEqual(try store.loadDeviceSnapshots(), [second])
    }
}

private final class DeviceSnapshotKeyValueStore: AppGroupKeyValueStoring, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        storage[key]
    }

    func set(_ value: Data?, forKey key: String) {
        storage[key] = value
    }
}
