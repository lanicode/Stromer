import Foundation

public struct BatteryMonitorRecord: Equatable, Sendable {
    public let productID: ProductID
    public let timeToGoMinutes: Int?
    public let batteryVoltage: Double?
    public let alarmReason: AlarmReason
    public let auxMode: AuxMode
    public let auxValue: BatteryAuxValue?
    public let batteryCurrent: Double?
    public let consumedAh: Double?
    public let soc: Double?

    public var modelName: String {
        productID.modelName
    }

    public var starterVoltage: Double? {
        guard case let .starterVoltage(value) = auxValue else {
            return nil
        }
        return value
    }

    public var midpointVoltage: Double? {
        guard case let .midpointVoltage(value) = auxValue else {
            return nil
        }
        return value
    }

    public var temperatureCelsius: Double? {
        guard case let .temperatureCelsius(value) = auxValue else {
            return nil
        }
        return value
    }

    static func parse(productID: ProductID, decrypted: Data) throws -> BatteryMonitorRecord {
        var reader = BitReader(decrypted)

        let timeToGoRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let batteryVoltageRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let alarmReasonRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let auxRaw = UInt16(try reader.readUnsignedInt(bitCount: 16))
        let auxModeRaw = UInt8(try reader.readUnsignedInt(bitCount: 2))
        let batteryCurrentRaw = UInt32(try reader.readUnsignedInt(bitCount: 22))
        let consumedAhRaw = UInt32(try reader.readUnsignedInt(bitCount: 20))
        let socRaw = UInt16(try reader.readUnsignedInt(bitCount: 10))

        let auxMode = AuxMode(rawValue: auxModeRaw) ?? .disabled

        return BatteryMonitorRecord(
            productID: productID,
            timeToGoMinutes: timeToGoRaw == 0xFFFF ? nil : Int(timeToGoRaw),
            batteryVoltage: scaledSigned16(batteryVoltageRaw, sentinel: 0x7FFF, divisor: 100),
            alarmReason: AlarmReason(rawValue: alarmReasonRaw),
            auxMode: auxMode,
            auxValue: makeAuxValue(raw: auxRaw, mode: auxMode),
            batteryCurrent: scaledBatteryCurrent(raw: batteryCurrentRaw),
            consumedAh: consumedAhRaw == 0x0F_FFFF ? nil : -Double(consumedAhRaw) / 10,
            soc: socRaw == 0x03FF ? nil : Double(socRaw) / 10
        )
    }
}

private func makeAuxValue(raw: UInt16, mode: AuxMode) -> BatteryAuxValue? {
    switch mode {
    case .starterVoltage:
        let signed = BitReader.toSignedInt(UInt64(raw), bitCount: 16)
        return .starterVoltage(Double(signed) / 100)
    case .midpointVoltage:
        return .midpointVoltage(Double(raw) / 100)
    case .temperature:
        let celsius = (Double(raw) / 100) - 273.15
        return .temperatureCelsius((celsius * 100).rounded() / 100)
    case .disabled:
        return nil
    }
}

private func scaledBatteryCurrent(raw: UInt32) -> Double? {
    guard raw != 0x3F_FFFF else {
        return nil
    }

    let signed = BitReader.toSignedInt(UInt64(raw), bitCount: 22)
    return Double(signed) / 1_000
}
