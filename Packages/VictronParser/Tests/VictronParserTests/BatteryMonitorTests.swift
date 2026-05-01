import Foundation
@testable import VictronParser
import XCTest

final class BatteryMonitorTests: XCTestCase {
    func testEndToEndParseFromPythonVector() throws {
        let payload = data("100289a302b040af925d09a4d89aa0128bdef48c6298a9")
        let key = data("aff4d0995b7d1e176c0c33ecb9e70dcd")

        guard case let .success(.batteryMonitor(record)) = parseVictronAdvertisement(
            manufacturerData: payload,
            key: key
        ) else {
            return XCTFail("Expected Battery Monitor parse success")
        }

        XCTAssertEqual(record.auxMode, .disabled)
        XCTAssertEqual(record.consumedAh ?? .nan, -50, accuracy: 0.0001)
        XCTAssertEqual(record.batteryCurrent ?? .nan, 0, accuracy: 0.0001)
        XCTAssertNil(record.timeToGoMinutes)
        XCTAssertEqual(record.soc ?? .nan, 50, accuracy: 0.0001)
        XCTAssertEqual(record.batteryVoltage ?? .nan, 12.53, accuracy: 0.0001)
        XCTAssertTrue(record.alarmReason.isEmpty)
        XCTAssertNil(record.temperatureCelsius)
        XCTAssertNil(record.starterVoltage)
        XCTAssertNil(record.midpointVoltage)
        XCTAssertEqual(record.modelName, "SmartShunt 500A/50mV")
    }

    func testParseDecryptedPythonVector() throws {
        let record = try BatteryMonitorRecord.parse(
            productID: ProductID(rawValue: 0xA389),
            decrypted: data("ffffe50400000000030000f40140df03")
        )

        XCTAssertEqual(record.auxMode, .disabled)
        XCTAssertEqual(record.consumedAh ?? .nan, -50, accuracy: 0.0001)
        XCTAssertEqual(record.batteryCurrent ?? .nan, 0, accuracy: 0.0001)
        XCTAssertNil(record.timeToGoMinutes)
        XCTAssertEqual(record.soc ?? .nan, 50, accuracy: 0.0001)
        XCTAssertEqual(record.batteryVoltage ?? .nan, 12.53, accuracy: 0.0001)
        XCTAssertTrue(record.alarmReason.isEmpty)
        XCTAssertNil(record.temperatureCelsius)
        XCTAssertNil(record.starterVoltage)
        XCTAssertNil(record.midpointVoltage)
    }

    func testAuxMidpointPythonVector() throws {
        let record = try BatteryMonitorRecord.parse(
            productID: ProductID(rawValue: 0xA389),
            decrypted: data("ffffe6040000feff010000000080fe0c")
        )

        XCTAssertEqual(record.midpointVoltage ?? .nan, 655.34, accuracy: 0.0001)
        XCTAssertNil(record.starterVoltage)
        XCTAssertNil(record.temperatureCelsius)
    }

    func testAuxStarterPythonVector() throws {
        let record = try BatteryMonitorRecord.parse(
            productID: ProductID(rawValue: 0xA389),
            decrypted: data("ffffe6040000feff000000000080feac")
        )

        XCTAssertEqual(record.starterVoltage ?? .nan, -0.02, accuracy: 0.0001)
        XCTAssertNil(record.midpointVoltage)
        XCTAssertNil(record.temperatureCelsius)
    }

    func testAuxTemperaturePythonVector() throws {
        let record = try BatteryMonitorRecord.parse(
            productID: ProductID(rawValue: 0xA389),
            decrypted: data("ffffe6040000ffff020000000080fede")
        )

        XCTAssertEqual(record.temperatureCelsius ?? .nan, 382.2, accuracy: 0.0001)
        XCTAssertNil(record.starterVoltage)
        XCTAssertNil(record.midpointVoltage)
    }

    func testKeyMismatchPythonVector() {
        let payload = data("100289a302bb01af129087600b9b97bc2c32867c8238da")
        let key = data("ffffffffffffffffffffffffffffffff")

        XCTAssertEqual(
            parseVictronAdvertisement(manufacturerData: payload, key: key),
            .wrongKey
        )
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
