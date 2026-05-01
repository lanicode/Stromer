import Foundation

public enum BitReaderError: Error, Equatable {
    case invalidBitCount(Int)
    case insufficientData(requiredBits: Int, availableBits: Int)
}

public struct BitReader {
    private let bytes: [UInt8]
    public private(set) var bitOffset: Int = 0

    public init(_ data: Data) {
        self.bytes = Array(data)
    }

    public var availableBits: Int {
        bytes.count * 8
    }

    public mutating func readUnsignedInt(bitCount: Int) throws -> UInt64 {
        guard (1...64).contains(bitCount) else {
            throw BitReaderError.invalidBitCount(bitCount)
        }

        let requiredBits = bitOffset + bitCount
        guard requiredBits <= availableBits else {
            throw BitReaderError.insufficientData(
                requiredBits: requiredBits,
                availableBits: availableBits
            )
        }

        var value: UInt64 = 0
        for position in 0..<bitCount {
            let absoluteBit = bitOffset + position
            let byte = bytes[absoluteBit >> 3]
            let bit = UInt64((byte >> UInt8(absoluteBit & 7)) & 1)
            value |= bit << UInt64(position)
        }

        bitOffset += bitCount
        return value
    }

    public mutating func readSignedInt(bitCount: Int) throws -> Int64 {
        let value = try readUnsignedInt(bitCount: bitCount)
        return Self.toSignedInt(value, bitCount: bitCount)
    }

    public static func toSignedInt(_ value: UInt64, bitCount: Int) -> Int64 {
        precondition((1...63).contains(bitCount))

        let signBit = UInt64(1) << UInt64(bitCount - 1)
        if value & signBit == 0 {
            return Int64(value)
        }

        return Int64(value) - (Int64(1) << Int64(bitCount))
    }
}
