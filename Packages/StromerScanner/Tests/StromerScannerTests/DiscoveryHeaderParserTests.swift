import Foundation
@testable import StromerScanner
import XCTest

final class DiscoveryHeaderParserTests: XCTestCase {
    func testParsesCompanyIncludedHeader() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: data("e102100289a302b040af925d09a4d89aa0128bdef48c6298a9")
        )

        XCTAssertEqual(header?.productAdvertisementVariant, 0x02)
        XCTAssertEqual(header?.productID, 0xA389)
        XCTAssertEqual(header?.recordType, 0x02)
        XCTAssertEqual(header?.nonce, 0x40B0)
        XCTAssertEqual(header?.keyCheckByte, 0xAF)
        XCTAssertEqual(header?.hasCompanyIdentifier, true)
        XCTAssertEqual(header?.encryptedPayloadLength, 15)
    }

    func testParsesStrippedHeader() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: data("100257a0010100ab000102030405060708090a0b0c0d0e0f")
        )

        XCTAssertEqual(header?.productID, 0xA057)
        XCTAssertEqual(header?.recordType, 0x01)
        XCTAssertEqual(header?.nonce, 0x0001)
        XCTAssertEqual(header?.keyCheckByte, 0xAB)
        XCTAssertEqual(header?.hasCompanyIdentifier, false)
    }

    func testRejectsShortData() {
        XCTAssertNil(DiscoveryHeaderParser.parseHeader(manufacturerData: Data()))
        XCTAssertNil(DiscoveryHeaderParser.parseHeader(manufacturerData: data("e102100289a302b0")))
    }

    func testRejectsWrongRecordMarker() {
        XCTAssertNil(
            DiscoveryHeaderParser.parseHeader(
                manufacturerData: data("e102110289a302b040af")
            )
        )
    }

    func testParsesOrionHeaderWithVariant00() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: orionManufacturerData(variant: 0x00)
        )

        assertOrionHeader(header, variant: 0x00)
    }

    func testParsesOrionHeaderWithVariant01() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: orionManufacturerData(variant: 0x01)
        )

        assertOrionHeader(header, variant: 0x01)
    }

    func testParsesOrionHeaderWithVariant03() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: orionManufacturerData(variant: 0x03)
        )

        assertOrionHeader(header, variant: 0x03)
    }

    func testParsesOrionHeaderWithVariantFF() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: orionManufacturerData(variant: 0xFF)
        )

        assertOrionHeader(header, variant: 0xFF)
    }

    func testParsesHeaderWithoutEncryptedPayload() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: data("e102100257a0010100ab")
        )

        XCTAssertEqual(header?.productID, 0xA057)
        XCTAssertEqual(header?.encryptedPayloadLength, 0)
    }
}

private func orionManufacturerData(variant: UInt8) -> Data {
    var bytes = data("e10210")
    bytes.append(variant)
    bytes.append(data("d0a30434127a000102030405060708090a0b0c0d0e0f"))
    return bytes
}

private func assertOrionHeader(
    _ header: DiscoveryHeader?,
    variant: UInt8,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(header?.productAdvertisementVariant, variant, file: file, line: line)
    XCTAssertEqual(header?.productID, 0xA3D0, file: file, line: line)
    XCTAssertEqual(header?.recordType, 0x04, file: file, line: line)
    XCTAssertEqual(header?.nonce, 0x1234, file: file, line: line)
    XCTAssertEqual(header?.keyCheckByte, 0x7A, file: file, line: line)
    XCTAssertEqual(header?.hasCompanyIdentifier, true, file: file, line: line)
    XCTAssertEqual(header?.encryptedPayloadLength, 16, file: file, line: line)
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
