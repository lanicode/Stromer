import Foundation
@testable import StromerScanner
import XCTest

final class DiscoveryHeaderParserTests: XCTestCase {
    func testParsesCompanyIncludedHeader() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: data("e102100289a302b040af925d09a4d89aa0128bdef48c6298a9")
        )

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

    func testRejectsWrongVictronPrefixByte() {
        XCTAssertNil(
            DiscoveryHeaderParser.parseHeader(
                manufacturerData: data("e102100189a302b040af")
            )
        )
    }

    func testParsesHeaderWithoutEncryptedPayload() {
        let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: data("e102100257a0010100ab")
        )

        XCTAssertEqual(header?.productID, 0xA057)
        XCTAssertEqual(header?.encryptedPayloadLength, 0)
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
