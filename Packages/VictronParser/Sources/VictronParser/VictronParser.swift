import Foundation

public enum VictronParseResult: Equatable, Sendable {
    case success(VictronRecord)
    case notVictron
    case unsupportedDevice(productID: UInt16, recordType: UInt8)
    case wrongKey
    case malformed(reason: String)
}

public enum VictronRecord: Equatable, Sendable {
    case solarCharger(SolarChargerRecord)
    case batteryMonitor(BatteryMonitorRecord)
    case dcDcConverter(DcDcConverterRecord)

    public var productID: ProductID {
        switch self {
        case let .solarCharger(record):
            return record.productID
        case let .batteryMonitor(record):
            return record.productID
        case let .dcDcConverter(record):
            return record.productID
        }
    }

    public var modelName: String {
        productID.modelName
    }
}

public func parseVictronAdvertisement(
    manufacturerData: Data,
    key: Data
) -> VictronParseResult {
    let advertisement: VictronAdvertisement
    do {
        advertisement = try VictronAdvertisement.parse(manufacturerData: manufacturerData)
    } catch VictronAdvertisementError.notVictron {
        return .notVictron
    } catch VictronAdvertisementError.malformed(let reason) {
        return .malformed(reason: reason)
    } catch {
        return .malformed(reason: String(describing: error))
    }

    guard key.count == 16 else {
        return .malformed(reason: "Victron advertisement key must be 16 bytes")
    }

    guard let deviceType = DeviceType(rawValue: advertisement.recordType) else {
        return .unsupportedDevice(
            productID: advertisement.productID.rawValue,
            recordType: advertisement.recordType
        )
    }

    guard key.first == advertisement.encryptionKeyFirstByte else {
        return .wrongKey
    }

    let decrypted: Data
    do {
        decrypted = try VictronDecryption.decrypt(
            encryptedPayload: advertisement.encryptedPayload,
            key: key,
            nonce: advertisement.nonce
        )
    } catch {
        return .malformed(reason: "Unable to decrypt Victron payload: \(error)")
    }

    do {
        switch deviceType {
        case .solarCharger:
            return .success(.solarCharger(
                try SolarChargerRecord.parse(
                    productID: advertisement.productID,
                    decrypted: decrypted
                )
            ))
        case .batteryMonitor:
            return .success(.batteryMonitor(
                try BatteryMonitorRecord.parse(
                    productID: advertisement.productID,
                    decrypted: decrypted
                )
            ))
        case .dcDcConverter:
            return .success(.dcDcConverter(
                try DcDcConverterRecord.parse(
                    productID: advertisement.productID,
                    decrypted: decrypted
                )
            ))
        }
    } catch {
        return .malformed(reason: "Unable to parse Victron payload: \(error)")
    }
}
