import Foundation
@testable import StromerScanner
import XCTest

@MainActor
final class DiscoveryStoreTests: XCTestCase {
    func testUpdateCreatesVisibleDiscoveredDevice() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })

        let device = store.update(rawAdvertisement: mpptAdvertisement(at: referenceDate))

        XCTAssertEqual(device?.productID, 0xA057)
        XCTAssertEqual(device?.estimatedDeviceType, .solarCharger)
        XCTAssertEqual(device?.supportStatus, .supported)
        XCTAssertEqual(device?.displayState, .full)
        XCTAssertEqual(device?.rssi, -55)
    }

    func testDisplayStateBecomesDimmedAfterThirtySeconds() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })

        store.update(rawAdvertisement: mpptAdvertisement(at: referenceDate))
        clock.now = referenceDate.addingTimeInterval(30)

        XCTAssertEqual(store.currentDevices().first?.displayState, .dimmed)
    }

    func testPruneRemovesDeviceAfterNinetySeconds() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })

        store.update(rawAdvertisement: mpptAdvertisement(at: referenceDate))
        clock.now = referenceDate.addingTimeInterval(91)

        XCTAssertTrue(store.currentDevices().isEmpty)
    }

    func testMultiDeviceUpdatesAreKeptSeparately() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })

        store.update(rawAdvertisement: mpptAdvertisement(at: referenceDate))
        store.update(rawAdvertisement: smartShuntAdvertisement(at: referenceDate.addingTimeInterval(1)))

        let devices = store.currentDevices()
        XCTAssertEqual(devices.count, 2)
        XCTAssertTrue(devices.contains { $0.productID == 0xA057 })
        XCTAssertTrue(devices.contains { $0.productID == 0xA389 })
    }

    func testRssiAndTimestampAreUpdatedForExistingPeripheral() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })
        let peripheralID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        store.update(rawAdvertisement: mpptAdvertisement(peripheralID: peripheralID, rssi: -70, at: referenceDate))
        store.update(
            rawAdvertisement: mpptAdvertisement(
                peripheralID: peripheralID,
                rssi: -42,
                at: referenceDate.addingTimeInterval(10)
            )
        )

        let device = store.currentDevices().first
        XCTAssertEqual(device?.rssi, -42)
        XCTAssertEqual(device?.lastSeenAt, referenceDate.addingTimeInterval(10))
    }

    func testRegisteredDeviceIsMarkedByPeripheralID() {
        let clock = TestClock(now: referenceDate)
        let peripheralID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let registered = TestDeviceBox(devices: [
            RegisteredDevice(
                name: "MPPT",
                advertisementKey: Data(repeating: 0, count: 16),
                peripheralID: peripheralID
            )
        ])
        let store = DiscoveryStore(now: { clock.now }, registeredDevices: { registered.devices })

        store.update(rawAdvertisement: mpptAdvertisement(peripheralID: peripheralID, at: referenceDate))

        XCTAssertEqual(store.currentDevices().first?.isRegistered, true)
    }

    func testMalformedAdvertisementIsIgnored() {
        let clock = TestClock(now: referenceDate)
        let store = DiscoveryStore(now: { clock.now })

        let result = store.update(
            rawAdvertisement: RawAdvertisement(
                peripheralID: UUID(),
                localName: nil,
                manufacturerData: Data([0x00, 0x01]),
                rssi: -99,
                timestamp: referenceDate
            )
        )

        XCTAssertNil(result)
        XCTAssertTrue(store.currentDevices().isEmpty)
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class TestDeviceBox: @unchecked Sendable {
    var devices: [RegisteredDevice]

    init(devices: [RegisteredDevice]) {
        self.devices = devices
    }
}

private func mpptAdvertisement(
    peripheralID: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
    rssi: Int = -55,
    at timestamp: Date
) -> RawAdvertisement {
    RawAdvertisement(
        peripheralID: peripheralID,
        localName: "SmartSolar",
        manufacturerData: data("e102100257a0010100ab000102030405060708090a0b0c0d0e0f"),
        rssi: rssi,
        timestamp: timestamp
    )
}

private func smartShuntAdvertisement(at timestamp: Date) -> RawAdvertisement {
    RawAdvertisement(
        peripheralID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        localName: "SmartShunt",
        manufacturerData: data("e102100289a302b040af925d09a4d89aa0128bdef48c6298a9"),
        rssi: -66,
        timestamp: timestamp
    )
}

private func data(_ hex: String) -> Data {
    var bytes = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        bytes.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }
    return bytes
}
