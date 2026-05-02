import Foundation
@testable import VictronParser
import XCTest

final class DcDcConverterRecordTests: XCTestCase {
    func testEndToEndParseFromPythonVector() throws {
        let payload = data("1000c0a304121d64ca8d442b90bbdf6a8cba")
        let key = data("64ba49f1a8562e45197a8e1fe50d7658")

        guard case let .success(.dcDcConverter(record)) = parseVictronAdvertisement(
            manufacturerData: payload,
            key: key
        ) else {
            return XCTFail("Expected DC/DC converter parse success")
        }

        XCTAssertEqual(record.productID.rawValue, 0xA3C0)
        XCTAssertEqual(record.chargeState, .off)
        XCTAssertEqual(record.chargerErrorCode, 0)
        XCTAssertEqual(record.inputVoltage ?? .nan, 13.15, accuracy: 0.0001)
        XCTAssertNil(record.outputVoltage)
        XCTAssertEqual(record.offReason, .engineShutdown)
        XCTAssertEqual(record.modelName, "Orion Smart 12V/12V-18A DC-DC Converter")
    }

    func testParseDecryptedPythonVector() throws {
        let record = try DcDcConverterRecord.parse(
            productID: ProductID(rawValue: 0xA3C0),
            decrypted: data("00002305ff7f80000000cbdd494cc5d1")
        )

        XCTAssertEqual(record.chargeState, .off)
        XCTAssertEqual(record.chargerErrorCode, 0)
        XCTAssertEqual(record.inputVoltage ?? .nan, 13.15, accuracy: 0.0001)
        XCTAssertNil(record.outputVoltage)
        XCTAssertEqual(record.offReason, .engineShutdown)
    }

    func testDeviceStateSentinelIsNil() throws {
        let record = try record(deviceState: 0xFF)

        XCTAssertNil(record.chargeState)
    }

    func testChargerErrorSentinelIsNil() throws {
        let record = try record(chargerError: 0xFF)

        XCTAssertNil(record.chargerErrorCode)
    }

    func testInputVoltageSentinelIsNil() throws {
        let record = try record(inputVoltage: 0xFFFF)

        XCTAssertNil(record.inputVoltage)
    }

    func testOutputVoltageSentinelIsCheckedBeforeSignedConversion() throws {
        let record = try record(outputVoltage: 0x7FFF)

        XCTAssertNil(record.outputVoltage)
    }

    func testNegativeOutputVoltageUsesSignedConversion() throws {
        let record = try record(outputVoltage: 0xFF38)

        XCTAssertEqual(record.outputVoltage ?? .nan, -2.00, accuracy: 0.0001)
    }

    func testUnknownOffReasonPreservesRawValue() throws {
        let record = try record(offReason: 0xFFFF_FF00)

        XCTAssertEqual(record.offReason.rawValue, 0xFFFF_FF00)
        XCTAssertNil(record.offReason.knownName)
        XCTAssertEqual(record.offReason.debugDescription, "0xFFFFFF00")
    }

    private func record(
        deviceState: UInt8 = 0,
        chargerError: UInt8 = 0,
        inputVoltage: UInt16 = 0x0523,
        outputVoltage: UInt16 = 0x0546,
        offReason: UInt32 = 0
    ) throws -> DcDcConverterRecord {
        try DcDcConverterRecord.parse(
            productID: ProductID(rawValue: 0xA3D0),
            decrypted: decryptedPayload(
                deviceState: deviceState,
                chargerError: chargerError,
                inputVoltage: inputVoltage,
                outputVoltage: outputVoltage,
                offReason: offReason
            )
        )
    }
}

private func decryptedPayload(
    deviceState: UInt8,
    chargerError: UInt8,
    inputVoltage: UInt16,
    outputVoltage: UInt16,
    offReason: UInt32
) -> Data {
    var bytes = Data([deviceState, chargerError])
    bytes.append(UInt8(inputVoltage & 0x00FF))
    bytes.append(UInt8(inputVoltage >> 8))
    bytes.append(UInt8(outputVoltage & 0x00FF))
    bytes.append(UInt8(outputVoltage >> 8))
    bytes.append(UInt8(offReason & 0x0000_00FF))
    bytes.append(UInt8((offReason & 0x0000_FF00) >> 8))
    bytes.append(UInt8((offReason & 0x00FF_0000) >> 16))
    bytes.append(UInt8((offReason & 0xFF00_0000) >> 24))
    bytes.append(contentsOf: repeatElement(UInt8(0), count: 6))
    return bytes
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
