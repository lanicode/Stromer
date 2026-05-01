import Foundation
@testable import VictronParser
import XCTest

final class HeaderTests: XCTestCase {
    func testParsesStrippedManufacturerPayload() throws {
        let advertisement = try VictronAdvertisement.parse(
            manufacturerData: data("100242a0016207adceb37b605d7e0ee21b24df5c")
        )

        XCTAssertFalse(advertisement.includesCompanyID)
        XCTAssertEqual(advertisement.productAdvertisementPrefix, 0x02)
        XCTAssertEqual(advertisement.productID.rawValue, 0xA042)
        XCTAssertEqual(advertisement.recordType, 0x01)
        XCTAssertEqual(advertisement.nonce, 0x0762)
        XCTAssertEqual(advertisement.encryptionKeyFirstByte, 0xAD)
    }

    func testParsesFullManufacturerDataWithCompanyID() throws {
        let advertisement = try VictronAdvertisement.parse(
            manufacturerData: data("e102100242a0016207adceb37b605d7e0ee21b24df5c")
        )

        XCTAssertTrue(advertisement.includesCompanyID)
        XCTAssertEqual(advertisement.productID.rawValue, 0xA042)
        XCTAssertEqual(advertisement.recordType, 0x01)
    }

    func testUnsupportedDeviceReturnsRecordTypeAndProductID() {
        let result = parseVictronAdvertisement(
            manufacturerData: data("100242a0030000ad00"),
            key: data("adeccb947395801a4dd45a2eaa44bf17")
        )

        XCTAssertEqual(result, .unsupportedDevice(productID: 0xA042, recordType: 0x03))
    }

    func testInvalidKeyLengthIsMalformed() {
        let result = parseVictronAdvertisement(
            manufacturerData: data("100242a0016207adceb37b605d7e0ee21b24df5c"),
            key: data("adeccb")
        )

        guard case let .malformed(reason) = result else {
            return XCTFail("Expected malformed for invalid key length")
        }

        XCTAssertTrue(reason.contains("16 bytes"))
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
