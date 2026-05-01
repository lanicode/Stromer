import Foundation
@testable import StromerScanner
import XCTest

final class AppGroupReadingStoreTests: XCTestCase {
    func testCodableRoundtripThroughMockBackingStore() throws {
        let backing = InMemoryKeyValueStore()
        let store = AppGroupReadingStore(backing: backing)
        let reading = sampleReading(deviceID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)

        try store.saveReadings([reading])

        XCTAssertEqual(try store.loadReadings(), [reading])
    }

    func testDeletesSingleReading() throws {
        let backing = InMemoryKeyValueStore()
        let store = AppGroupReadingStore(backing: backing)
        let firstID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let secondID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        try store.saveReadings([
            sampleReading(deviceID: firstID),
            sampleReading(deviceID: secondID)
        ])
        try store.deleteReading(deviceID: firstID)

        XCTAssertEqual(try store.loadReadings().map(\.deviceID), [secondID])
    }
}

private final class InMemoryKeyValueStore: AppGroupKeyValueStoring, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        storage[key]
    }

    func set(_ value: Data?, forKey key: String) {
        storage[key] = value
    }
}

private func sampleReading(deviceID: UUID) -> DeviceReading {
    DeviceReading(
        id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        deviceID: deviceID,
        name: "SmartShunt",
        localName: "SmartShunt HT",
        peripheralID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        productID: 0xA389,
        recordType: 0x02,
        modelName: "SmartShunt 500A/50mV",
        rssi: -70,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        freshness: .fresh,
        payload: .batteryMonitor(BatteryMonitorReading(
            timeToGoMinutes: nil,
            batteryVoltage: 12.53,
            alarmReasonRaw: 0,
            auxModeRaw: 3,
            starterVoltage: nil,
            midpointVoltage: nil,
            temperatureCelsius: nil,
            batteryCurrent: 0,
            consumedAh: -50,
            soc: 50
        ))
    )
}
