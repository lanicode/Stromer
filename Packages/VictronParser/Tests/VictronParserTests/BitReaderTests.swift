import Foundation
@testable import VictronParser
import XCTest

final class BitReaderTests: XCTestCase {
    func testReadsLeastSignificantBitsFirst() throws {
        var reader = BitReader(Data([0b1010_1100]))

        XCTAssertEqual(try reader.readUnsignedInt(bitCount: 4), 0b1100)
        XCTAssertEqual(reader.bitOffset, 4)
        XCTAssertEqual(try reader.readUnsignedInt(bitCount: 4), 0b1010)
    }

    func testReadsLittleEndianAlignedIntegers() throws {
        var reader = BitReader(Data([0x34, 0x12]))

        XCTAssertEqual(try reader.readUnsignedInt(bitCount: 16), 0x1234)
    }

    func testReadsAcrossByteBoundary() throws {
        var reader = BitReader(Data([0b1111_0000, 0b0000_1010]))

        XCTAssertEqual(try reader.readUnsignedInt(bitCount: 6), 0b11_0000)
        XCTAssertEqual(try reader.readUnsignedInt(bitCount: 6), 0b1010_11)
    }

    func testTwoComplementConversionForArbitraryWidth() {
        XCTAssertEqual(BitReader.toSignedInt(0, bitCount: 22), 0)
        XCTAssertEqual(BitReader.toSignedInt(0x1F_FFFF, bitCount: 22), 2_097_151)
        XCTAssertEqual(BitReader.toSignedInt(0x20_0000, bitCount: 22), -2_097_152)
        XCTAssertEqual(BitReader.toSignedInt(0x3F_FFFF, bitCount: 22), -1)
    }

    func testInsufficientDataThrows() {
        var reader = BitReader(Data([0x00]))

        XCTAssertThrowsError(try reader.readUnsignedInt(bitCount: 9)) { error in
            XCTAssertEqual(
                error as? BitReaderError,
                .insufficientData(requiredBits: 9, availableBits: 8)
            )
        }
    }
}
