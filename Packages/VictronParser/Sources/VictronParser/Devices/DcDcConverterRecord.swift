import Foundation

public struct DcDcConverterRecord: Equatable, Sendable {
    public let productID: ProductID
    public let chargeState: ChargerState?
    public let chargerErrorCode: UInt8?
    public let inputVoltage: Double?
    public let outputVoltage: Double?
    public let offReason: DcDcOffReason

    public var modelName: String {
        productID.modelName
    }

    static func parse(productID: ProductID, decrypted: Data) throws -> DcDcConverterRecord {
        var reader = BitReader(decrypted)

        let chargeStateRaw = UInt8(try reader.readUnsignedInt(bitCount: 8))
        let chargerErrorRaw = UInt8(try reader.readUnsignedInt(bitCount: 8))
        let inputVoltageRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let outputVoltageRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let offReasonRaw = UInt32(try reader.readUnsignedInt(bitCount: 32))

        return DcDcConverterRecord(
            productID: productID,
            chargeState: chargeStateRaw == 0xFF ? nil : ChargerState(rawValue: chargeStateRaw),
            chargerErrorCode: chargerErrorRaw == 0xFF ? nil : chargerErrorRaw,
            inputVoltage: inputVoltageRaw == 0xFFFF ? nil : Double(inputVoltageRaw) / 100,
            outputVoltage: scaledSigned16(outputVoltageRaw, sentinel: 0x7FFF, divisor: 100),
            offReason: DcDcOffReason(rawValue: offReasonRaw)
        )
    }
}
