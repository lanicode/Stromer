import Foundation
@testable import StromerScanner
import XCTest

final class WidgetSnapshotProviderTests: XCTestCase {
    func testSnapshotShowsPlaceholderWhenNoDevicesAreRegistered() {
        let provider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([]),
            readingStore: WidgetReadingStore([]),
            now: { referenceDate }
        )

        let snapshot = provider.snapshot(selectedDeviceID: nil)

        XCTAssertEqual(snapshot.status, .noDevices)
        XCTAssertEqual(snapshot.message, "Gerät in Stromer hinzufügen")
        XCTAssertTrue(snapshot.devices.isEmpty)
    }

    func testDeviceOptionsEmptyOneAndMany() throws {
        let emptyProvider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([]),
            readingStore: WidgetReadingStore([]),
            now: { referenceDate }
        )
        XCTAssertEqual(try emptyProvider.deviceOptions(), [])

        let oneProvider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([batteryDevice]),
            readingStore: WidgetReadingStore([]),
            now: { referenceDate }
        )
        XCTAssertEqual(try oneProvider.deviceOptions(), [
            StromerWidgetDeviceOption(id: batteryDevice.id, name: "SmartShunt")
        ])

        let manyProvider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([solarDevice, batteryDevice]),
            readingStore: WidgetReadingStore([]),
            now: { referenceDate }
        )
        XCTAssertEqual(try manyProvider.deviceOptions().map(\.name), ["MPPT", "SmartShunt"])
    }

    func testTimelineGenerationUsesSelectedDeviceAndReloadPolicy() {
        let provider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([batteryDevice, solarDevice]),
            readingStore: WidgetReadingStore([batteryReading, solarReading]),
            now: { referenceDate },
            reloadInterval: 1_800
        )

        let timeline = provider.timeline(
            selectedDeviceID: solarDevice.id,
            maxDevices: 2
        )

        XCTAssertEqual(timeline.entries.count, 1)
        XCTAssertEqual(timeline.entries.first?.devices.map(\.name), ["MPPT", "SmartShunt"])
        XCTAssertEqual(timeline.reloadAfter, referenceDate.addingTimeInterval(1_800))
    }

    func testMissingSelectedDeviceDoesNotCrash() {
        let provider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([batteryDevice]),
            readingStore: WidgetReadingStore([batteryReading]),
            now: { referenceDate }
        )

        let snapshot = provider.snapshot(
            selectedDeviceID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        )

        XCTAssertEqual(snapshot.status, .deviceMissing)
        XCTAssertEqual(snapshot.message, "Gerät nicht mehr vorhanden")
        XCTAssertTrue(snapshot.devices.isEmpty)
    }

    func testStaleReadingDisplayInSnapshot() {
        let provider = StromerWidgetSnapshotProvider(
            deviceStore: WidgetDeviceStore([batteryDevice]),
            readingStore: WidgetReadingStore([batteryReading]),
            now: { referenceDate.addingTimeInterval(601) }
        )

        let snapshot = provider.snapshot(selectedDeviceID: batteryDevice.id)
        let device = snapshot.devices.first

        XCTAssertEqual(device?.freshness, .stale)
        XCTAssertEqual(device?.relativeLastUpdated, "vor 10 Min.")
        XCTAssertEqual(device?.mainValue, "51")
        XCTAssertEqual(device?.mainUnit, "%")
        XCTAssertEqual(device?.secondary, "12,53 V • -2,10 A")
        XCTAssertEqual(device?.isDimmed, true)
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

private let batteryDevice = RegisteredDeviceSnapshot(
    id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    name: "SmartShunt",
    productID: 0xA389,
    recordType: 0x02,
    lastSeenAt: referenceDate,
    lastRSSI: -68
)

private let solarDevice = RegisteredDeviceSnapshot(
    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
    name: "MPPT",
    productID: 0xA042,
    recordType: 0x01,
    lastSeenAt: referenceDate,
    lastRSSI: -62
)

private let batteryReading = DeviceReading(
    deviceID: batteryDevice.id,
    name: batteryDevice.name,
    localName: "SmartShunt HT",
    peripheralID: nil,
    productID: 0xA389,
    recordType: 0x02,
    modelName: "SmartShunt 500A/50mV",
    rssi: -68,
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
        batteryCurrent: -2.1,
        consumedAh: -20,
        soc: 51
    ))
)

private let solarReading = DeviceReading(
    deviceID: solarDevice.id,
    name: solarDevice.name,
    localName: "MPPT",
    peripheralID: nil,
    productID: 0xA042,
    recordType: 0x01,
    modelName: "SmartSolar MPPT",
    rssi: -62,
    timestamp: referenceDate,
    freshness: .fresh,
    payload: .solarCharger(SolarChargerReading(
        deviceStateRaw: 3,
        chargerErrorCode: nil,
        batteryVoltage: 13.2,
        batteryCurrent: 4.1,
        yieldTodayWh: 420,
        pvPower: 87,
        loadCurrent: nil
    ))
)

private final class WidgetDeviceStore: RegisteredDeviceSnapshotStoring, @unchecked Sendable {
    private var devices: [RegisteredDeviceSnapshot]

    init(_ devices: [RegisteredDeviceSnapshot]) {
        self.devices = devices
    }

    func saveDeviceSnapshots(_ snapshots: [RegisteredDeviceSnapshot]) throws {
        devices = snapshots
    }

    func loadDeviceSnapshots() throws -> [RegisteredDeviceSnapshot] {
        devices
    }

    func deleteDeviceSnapshot(id: UUID) throws {
        devices.removeAll { $0.id == id }
    }
}

private final class WidgetReadingStore: ReadingStoring, @unchecked Sendable {
    private var readings: [DeviceReading]

    init(_ readings: [DeviceReading]) {
        self.readings = readings
    }

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
