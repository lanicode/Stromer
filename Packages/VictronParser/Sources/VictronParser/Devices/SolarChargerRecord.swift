import Foundation

public struct SolarChargerRecord: Equatable, Sendable {
    public let productID: ProductID
    public let deviceState: ChargerState?
    public let chargerErrorCode: UInt8?
    public let batteryVoltage: Double?
    public let batteryCurrent: Double?
    public let yieldTodayWh: Double?
    public let pvPower: Int?
    public let loadCurrent: Double?

    public var modelName: String {
        productID.modelName
    }

    static func parse(productID: ProductID, decrypted: Data) throws -> SolarChargerRecord {
        var reader = BitReader(decrypted)

        let deviceStateRaw = UInt8(try reader.readUnsignedInt(bitCount: 8))
        let chargerErrorRaw = UInt8(try reader.readUnsignedInt(bitCount: 8))
        let batteryVoltageRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let batteryCurrentRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let yieldTodayRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let pvPowerRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let loadCurrentRaw = UInt16(try reader.readUnsignedInt(bitCount: 9))

        return SolarChargerRecord(
            productID: productID,
            deviceState: deviceStateRaw == 0xFF ? nil : ChargerState(rawValue: deviceStateRaw),
            chargerErrorCode: chargerErrorRaw == 0xFF ? nil : chargerErrorRaw,
            batteryVoltage: scaledSigned16(batteryVoltageRaw, sentinel: 0x7FFF, divisor: 100),
            batteryCurrent: scaledSigned16(batteryCurrentRaw, sentinel: 0x7FFF, divisor: 10),
            yieldTodayWh: yieldTodayRaw == 0xFFFF ? nil : Double(yieldTodayRaw) * 10,
            pvPower: pvPowerRaw == 0xFFFF ? nil : Int(pvPowerRaw),
            loadCurrent: loadCurrentRaw == 0x01FF ? nil : Double(loadCurrentRaw) / 10
        )
    }
}

func scaledSigned16(_ raw: UInt16, sentinel: UInt16, divisor: Double) -> Double? {
    guard raw != sentinel else {
        return nil
    }

    let signed = BitReader.toSignedInt(UInt64(raw), bitCount: 16)
    return Double(signed) / divisor
}
