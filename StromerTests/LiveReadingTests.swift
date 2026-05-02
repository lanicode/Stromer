import Foundation
@testable import StromerScanner
import SwiftData
import XCTest

@MainActor
final class LiveReadingTests: XCTestCase {
    func testBatteryPayloadConvertsToLiveReadingFields() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let reading = makeBatteryReading(timestamp: timestamp, soc: 82, voltage: 12.72, current: -2.4)

        let live = LiveReading(reading: reading)

        XCTAssertEqual(live.deviceID, reading.deviceID)
        XCTAssertEqual(live.timestamp, timestamp)
        XCTAssertEqual(live.familyKind, "battery")
        XCTAssertEqual(live.voltage, 12.72)
        XCTAssertEqual(live.current, -2.4)
        XCTAssertEqual(live.soc, 82)
        XCTAssertNil(live.pvPower)
        XCTAssertNil(live.outputVoltage)
    }

    func testSolarPayloadConvertsToLiveReadingFields() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let reading = makeSolarReading(timestamp: timestamp, pvPower: 312, yieldToday: 1_420)

        let live = LiveReading(reading: reading)

        XCTAssertEqual(live.familyKind, "solar")
        XCTAssertEqual(live.pvPower, 312)
        XCTAssertEqual(live.yieldToday, 1_420)
        XCTAssertEqual(live.batteryVoltage, 13.91)
        XCTAssertEqual(live.batteryCurrent, 18.4)
        XCTAssertNil(live.soc)
    }

    func testDcDcPayloadConvertsToLiveReadingFields() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let reading = makeDcDcReading(timestamp: timestamp, inputVoltage: 13.1, outputVoltage: 14.2)

        let live = LiveReading(reading: reading)

        XCTAssertEqual(live.familyKind, "dcdc")
        XCTAssertEqual(live.inputVoltage, 13.1)
        XCTAssertEqual(live.outputVoltage, 14.2)
        XCTAssertEqual(live.dcDcChargeStateRaw, 3)
        XCTAssertEqual(live.offReasonRaw, 0)
        XCTAssertNil(live.pvPower)
    }
}

@MainActor
func makeHistoryStore(now: @escaping () -> Date = Date.init) throws -> SwiftDataHistoryStore {
    let schema = SwiftDataHistoryStore.schema
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return try SwiftDataHistoryStore(container: container, nowProvider: now)
}

func makeBatteryReading(
    deviceID: UUID = UUID(),
    timestamp: Date,
    soc: Double? = 80,
    voltage: Double? = 12.7,
    current: Double? = -1.2
) -> DeviceReading {
    DeviceReading(
        deviceID: deviceID,
        name: "House Battery",
        localName: "SmartShunt",
        peripheralID: UUID(),
        productID: 0xA389,
        recordType: 0x02,
        modelName: "SmartShunt",
        rssi: -62,
        timestamp: timestamp,
        freshness: DeviceFreshness(lastSeenAt: timestamp, now: timestamp),
        payload: .batteryMonitor(BatteryMonitorReading(
            timeToGoMinutes: 120,
            batteryVoltage: voltage,
            alarmReasonRaw: 0,
            auxModeRaw: 0,
            starterVoltage: nil,
            midpointVoltage: nil,
            temperatureCelsius: 21.5,
            batteryCurrent: current,
            consumedAh: 12.3,
            soc: soc
        ))
    )
}

func makeSolarReading(
    deviceID: UUID = UUID(),
    timestamp: Date,
    pvPower: Int? = 250,
    yieldToday: Double? = 850
) -> DeviceReading {
    DeviceReading(
        deviceID: deviceID,
        name: "Roof Solar",
        localName: "SmartSolar",
        peripheralID: UUID(),
        productID: 0xA057,
        recordType: 0x01,
        modelName: "SmartSolar MPPT",
        rssi: -70,
        timestamp: timestamp,
        freshness: DeviceFreshness(lastSeenAt: timestamp, now: timestamp),
        payload: .solarCharger(SolarChargerReading(
            deviceStateRaw: 3,
            chargerErrorCode: nil,
            batteryVoltage: 13.91,
            batteryCurrent: 18.4,
            yieldTodayWh: yieldToday,
            pvPower: pvPower,
            loadCurrent: 0.4
        ))
    )
}

func makeDcDcReading(
    deviceID: UUID = UUID(),
    timestamp: Date,
    inputVoltage: Double? = 13.1,
    outputVoltage: Double? = 14.2
) -> DeviceReading {
    DeviceReading(
        deviceID: deviceID,
        name: "Orion",
        localName: "Orion Smart",
        peripheralID: UUID(),
        productID: 0xA3D0,
        recordType: 0x04,
        modelName: "Orion Smart",
        rssi: -68,
        timestamp: timestamp,
        freshness: DeviceFreshness(lastSeenAt: timestamp, now: timestamp),
        payload: .dcDcConverter(DcDcConverterReading(
            chargeStateRaw: 3,
            chargerErrorCode: nil,
            inputVoltage: inputVoltage,
            outputVoltage: outputVoltage,
            offReasonRaw: 0
        ))
    )
}
