import Foundation
@testable import VictronParser
import XCTest

final class SolarChargerTests: XCTestCase {
    func testEndToEndParseFromPythonVector() throws {
        let payload = data("100242a0016207adceb37b605d7e0ee21b24df5c")
        let key = data("adeccb947395801a4dd45a2eaa44bf17")

        guard case let .success(.solarCharger(record)) = parseVictronAdvertisement(
            manufacturerData: payload,
            key: key
        ) else {
            return XCTFail("Expected Solar Charger parse success")
        }

        XCTAssertEqual(record.deviceState, .absorption)
        XCTAssertEqual(record.batteryVoltage ?? .nan, 13.88, accuracy: 0.0001)
        XCTAssertEqual(record.batteryCurrent ?? .nan, 1.4, accuracy: 0.0001)
        XCTAssertEqual(record.yieldTodayWh ?? .nan, 30, accuracy: 0.0001)
        XCTAssertEqual(record.pvPower, 19)
        XCTAssertEqual(record.loadCurrent ?? .nan, 0, accuracy: 0.0001)
        XCTAssertEqual(record.modelName, "BlueSolar Charger MPPT 75/15")
    }

    func testParseDecryptedPythonVector() throws {
        let record = try SolarChargerRecord.parse(
            productID: ProductID(rawValue: 0xA042),
            decrypted: data("04006c050e000300130000fe409ac069")
        )

        XCTAssertEqual(record.deviceState, .absorption)
        XCTAssertEqual(record.batteryVoltage ?? .nan, 13.88, accuracy: 0.0001)
        XCTAssertEqual(record.batteryCurrent ?? .nan, 1.4, accuracy: 0.0001)
        XCTAssertEqual(record.yieldTodayWh ?? .nan, 30, accuracy: 0.0001)
        XCTAssertEqual(record.pvPower, 19)
        XCTAssertEqual(record.loadCurrent ?? .nan, 0, accuracy: 0.0001)
    }

    func testBulkChargePythonVector() throws {
        let record = try SolarChargerRecord.parse(
            productID: ProductID(rawValue: 0xA042),
            decrypted: data("0300f80402000200030000fe8c9a5572")
        )

        XCTAssertEqual(record.deviceState, .bulk)
    }

    func testMPPT100PythonVector() throws {
        let record = try SolarChargerRecord.parse(
            productID: ProductID(rawValue: 0xA057),
            decrypted: data("0300fb09650032000901ffff31bc45ad")
        )

        XCTAssertEqual(record.batteryCurrent ?? .nan, 10.1, accuracy: 0.0001)
        XCTAssertEqual(record.batteryVoltage ?? .nan, 25.55, accuracy: 0.0001)
        XCTAssertEqual(record.deviceState, .bulk)
        XCTAssertEqual(record.pvPower, 265)
        XCTAssertEqual(record.yieldTodayWh ?? .nan, 500, accuracy: 0.0001)
        XCTAssertNil(record.loadCurrent)
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
