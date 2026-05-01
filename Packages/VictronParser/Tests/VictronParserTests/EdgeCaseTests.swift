import Foundation
@testable import VictronParser
import XCTest

final class EdgeCaseTests: XCTestCase {
    func testEmptyDataIsMalformed() {
        guard case .malformed = parseVictronAdvertisement(
            manufacturerData: Data(),
            key: validBatteryKey
        ) else {
            return XCTFail("Expected malformed for empty data")
        }
    }

    func testShortDataIsMalformed() {
        guard case .malformed = parseVictronAdvertisement(
            manufacturerData: data("1002"),
            key: validBatteryKey
        ) else {
            return XCTFail("Expected malformed for short Victron payload")
        }
    }

    func testWrongCompanyIDIsNotVictron() {
        XCTAssertEqual(
            parseVictronAdvertisement(
                manufacturerData: data("0002100289a302b040af925d09a4d89aa0128bdef48c6298a9"),
                key: validBatteryKey
            ),
            .notVictron
        )
    }

    func testWrongRecordMarkerIsNotVictron() {
        XCTAssertEqual(
            parseVictronAdvertisement(
                manufacturerData: data("110289a302b040af925d09a4d89aa0128bdef48c6298a9"),
                key: validBatteryKey
            ),
            .notVictron
        )
    }

    func testWrongKeyCheckByteReturnsWrongKey() {
        XCTAssertEqual(
            parseVictronAdvertisement(
                manufacturerData: data("100289a302bb01af129087600b9b97bc2c32867c8238da"),
                key: data("ffffffffffffffffffffffffffffffff")
            ),
            .wrongKey
        )
    }

    func testSolarNASentinelsPerField() throws {
        XCTAssertNil(try solar(deviceState: 0xFF).deviceState)
        XCTAssertNil(try solar(chargerError: 0xFF).chargerErrorCode)
        XCTAssertNil(try solar(batteryVoltage: 0x7FFF).batteryVoltage)
        XCTAssertNil(try solar(batteryCurrent: 0x7FFF).batteryCurrent)
        XCTAssertNil(try solar(yieldToday: 0xFFFF).yieldTodayWh)
        XCTAssertNil(try solar(pvPower: 0xFFFF).pvPower)
        XCTAssertNil(try solar(loadCurrent: 0x01FF).loadCurrent)
    }

    func testBatteryMonitorNASentinelsPerField() throws {
        XCTAssertNil(try battery(timeToGo: 0xFFFF).timeToGoMinutes)
        XCTAssertNil(try battery(batteryVoltage: 0x7FFF).batteryVoltage)
        XCTAssertNil(try battery(batteryCurrent: 0x3F_FFFF).batteryCurrent)
        XCTAssertNil(try battery(consumedAh: 0x0F_FFFF).consumedAh)
        XCTAssertNil(try battery(soc: 0x03FF).soc)
    }

    func testDisabledAuxModeIgnoresAuxValue() throws {
        let record = try battery(auxValue: 0xFFFF, auxMode: UInt64(AuxMode.disabled.rawValue))

        XCTAssertEqual(record.auxMode, .disabled)
        XCTAssertNil(record.auxValue)
        XCTAssertNil(record.starterVoltage)
        XCTAssertNil(record.midpointVoltage)
        XCTAssertNil(record.temperatureCelsius)
    }

    func testCombinedAlarmReasonFlags() throws {
        let record = try battery(alarmReason: 0x0005)

        XCTAssertEqual(record.alarmReason.rawValue, 0x0005)
        XCTAssertTrue(record.alarmReason.contains(.lowVoltage))
        XCTAssertTrue(record.alarmReason.contains(.lowSOC))
        XCTAssertTrue(record.alarmReason.hasLowVoltage)
        XCTAssertTrue(record.alarmReason.hasLowSOC)
        XCTAssertFalse(record.alarmReason.contains(.highVoltage))
    }

    func testUnknownProductIDStillParses() {
        var bytes = Array(data("100289a302b040af925d09a4d89aa0128bdef48c6298a9"))
        bytes[2] = 0xFF
        bytes[3] = 0xFF

        guard case let .success(.batteryMonitor(record)) = parseVictronAdvertisement(
            manufacturerData: Data(bytes),
            key: validBatteryKey
        ) else {
            return XCTFail("Expected unknown Product ID to parse")
        }

        XCTAssertEqual(record.productID.rawValue, 0xFFFF)
        XCTAssertEqual(record.modelName, "<Unknown device: 65535>")
    }
}

private let validBatteryKey = data("aff4d0995b7d1e176c0c33ecb9e70dcd")

private func solar(
    deviceState: UInt64 = 4,
    chargerError: UInt64 = 0,
    batteryVoltage: UInt64 = 1_388,
    batteryCurrent: UInt64 = 14,
    yieldToday: UInt64 = 3,
    pvPower: UInt64 = 19,
    loadCurrent: UInt64 = 0
) throws -> SolarChargerRecord {
    try SolarChargerRecord.parse(
        productID: ProductID(rawValue: 0xA042),
        decrypted: solarPayload(
            deviceState: deviceState,
            chargerError: chargerError,
            batteryVoltage: batteryVoltage,
            batteryCurrent: batteryCurrent,
            yieldToday: yieldToday,
            pvPower: pvPower,
            loadCurrent: loadCurrent
        )
    )
}

private func battery(
    timeToGo: UInt64 = 10,
    batteryVoltage: UInt64 = 1_253,
    alarmReason: UInt64 = 0,
    auxValue: UInt64 = 0,
    auxMode: UInt64 = UInt64(AuxMode.disabled.rawValue),
    batteryCurrent: UInt64 = 0,
    consumedAh: UInt64 = 500,
    soc: UInt64 = 500
) throws -> BatteryMonitorRecord {
    try BatteryMonitorRecord.parse(
        productID: ProductID(rawValue: 0xA389),
        decrypted: batteryPayload(
            timeToGo: timeToGo,
            batteryVoltage: batteryVoltage,
            alarmReason: alarmReason,
            auxValue: auxValue,
            auxMode: auxMode,
            batteryCurrent: batteryCurrent,
            consumedAh: consumedAh,
            soc: soc
        )
    )
}

private func solarPayload(
    deviceState: UInt64,
    chargerError: UInt64,
    batteryVoltage: UInt64,
    batteryCurrent: UInt64,
    yieldToday: UInt64,
    pvPower: UInt64,
    loadCurrent: UInt64
) -> Data {
    var packer = BitPacker()
    packer.append(deviceState, bitCount: 8)
    packer.append(chargerError, bitCount: 8)
    packer.append(batteryVoltage, bitCount: 16)
    packer.append(batteryCurrent, bitCount: 16)
    packer.append(yieldToday, bitCount: 16)
    packer.append(pvPower, bitCount: 16)
    packer.append(loadCurrent, bitCount: 9)
    return packer.data()
}

private func batteryPayload(
    timeToGo: UInt64,
    batteryVoltage: UInt64,
    alarmReason: UInt64,
    auxValue: UInt64,
    auxMode: UInt64,
    batteryCurrent: UInt64,
    consumedAh: UInt64,
    soc: UInt64
) -> Data {
    var packer = BitPacker()
    packer.append(timeToGo, bitCount: 16)
    packer.append(batteryVoltage, bitCount: 16)
    packer.append(alarmReason, bitCount: 16)
    packer.append(auxValue, bitCount: 16)
    packer.append(auxMode, bitCount: 2)
    packer.append(batteryCurrent, bitCount: 22)
    packer.append(consumedAh, bitCount: 20)
    packer.append(soc, bitCount: 10)
    return packer.data()
}

private struct BitPacker {
    private var bits: [UInt8] = []

    mutating func append(_ value: UInt64, bitCount: Int) {
        for position in 0..<bitCount {
            bits.append(UInt8((value >> UInt64(position)) & 1))
        }
    }

    func data() -> Data {
        var bytes = [UInt8](repeating: 0, count: (bits.count + 7) / 8)

        for (index, bit) in bits.enumerated() where bit == 1 {
            bytes[index / 8] |= UInt8(1) << UInt8(index & 7)
        }

        return Data(bytes)
    }
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
