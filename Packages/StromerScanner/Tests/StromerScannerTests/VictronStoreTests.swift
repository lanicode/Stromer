import Foundation
@testable import StromerScanner
import VictronParser
import XCTest

@MainActor
final class VictronStoreTests: XCTestCase {
    func testReadingUpdatesAndPersists() throws {
        let readingStore = InMemoryReadingStore()
        let store = VictronStore(readingStore: readingStore, now: { referenceDate })
        let device = RegisteredDevice(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "SmartShunt",
            advertisementKey: batteryKey,
            peripheralID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            localName: "SmartShunt HT"
        )
        let record = try batteryRecord()
        let advertisement = RawAdvertisement(
            peripheralID: device.peripheralID!,
            localName: device.localName,
            manufacturerData: batteryAdvertisement,
            rssi: -72,
            timestamp: referenceDate
        )

        let reading = try store.update(
            device: device,
            record: record,
            advertisement: advertisement
        )

        XCTAssertEqual(reading.deviceID, device.id)
        XCTAssertEqual(reading.freshness, .fresh)
        XCTAssertEqual(store.latestReadings, [reading])
        XCTAssertEqual(try readingStore.loadReadings(), [reading])
    }

    func testRecalculateFreshness() throws {
        let readingStore = InMemoryReadingStore()
        let store = VictronStore(readingStore: readingStore, now: { referenceDate })
        let device = RegisteredDevice(name: "SmartShunt", advertisementKey: batteryKey)
        let advertisement = RawAdvertisement(
            peripheralID: UUID(),
            localName: nil,
            manufacturerData: batteryAdvertisement,
            rssi: -72,
            timestamp: referenceDate
        )

        _ = try store.update(
            device: device,
            record: try batteryRecord(),
            advertisement: advertisement
        )
        try store.recalculateFreshness(now: referenceDate.addingTimeInterval(601))

        XCTAssertEqual(store.latestReadings.first?.freshness, .stale)
        XCTAssertEqual(try readingStore.loadReadings().first?.freshness, .stale)
    }

    func testLoadsPersistedReadings() throws {
        let readingStore = InMemoryReadingStore()
        let expected = sampleReading(deviceID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)
        try readingStore.saveReadings([expected])
        let store = VictronStore(readingStore: readingStore)

        try store.loadPersistedReadings()

        XCTAssertEqual(store.latestReadings, [expected])
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
private let batteryKey = data("aff4d0995b7d1e176c0c33ecb9e70dcd")
private let batteryAdvertisement = data("100289a302b040af925d09a4d89aa0128bdef48c6298a9")

private final class InMemoryReadingStore: ReadingStoring, @unchecked Sendable {
    private var readings: [DeviceReading] = []

    func saveReadings(_ readings: [DeviceReading]) throws {
        self.readings = readings
    }

    func loadReadings() throws -> [DeviceReading] {
        readings
    }

    func deleteReading(deviceID: UUID) throws {
        readings.removeAll { $0.deviceID == deviceID }
    }
}

private func batteryRecord() throws -> VictronRecord {
    guard case let .success(record) = parseVictronAdvertisement(
        manufacturerData: batteryAdvertisement,
        key: batteryKey
    ) else {
        throw ScannerError.noMatchingDevice
    }

    return record
}

private func sampleReading(deviceID: UUID) -> DeviceReading {
    DeviceReading(
        id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        deviceID: deviceID,
        name: "SmartShunt",
        localName: nil,
        peripheralID: nil,
        productID: 0xA389,
        recordType: 0x02,
        modelName: "SmartShunt 500A/50mV",
        rssi: -70,
        timestamp: referenceDate,
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
