import Foundation

enum VictronAdvertisementError: Error, Equatable {
    case notVictron
    case malformed(String)
}

public struct VictronAdvertisement: Equatable, Sendable {
    public static let companyID: UInt16 = 0x02E1
    public static let productAdvertisementRecordType: UInt8 = 0x10
    static let minimumPayloadLength = 8

    public let productAdvertisementPrefix: UInt8
    public let productID: ProductID
    public let recordType: UInt8
    public let nonce: UInt16
    public let encryptionKeyFirstByte: UInt8
    public let encryptedPayload: Data
    public let includesCompanyID: Bool

    static func parse(manufacturerData: Data) throws -> VictronAdvertisement {
        let bytes = Array(manufacturerData)

        guard !bytes.isEmpty else {
            throw VictronAdvertisementError.malformed("Manufacturer data is empty")
        }

        let payloadStart: Int
        if bytes.count >= 2,
           bytes[0] == UInt8(truncatingIfNeeded: companyID),
           bytes[1] == UInt8(truncatingIfNeeded: companyID >> 8) {
            payloadStart = 2
        } else if bytes[0] == productAdvertisementRecordType {
            payloadStart = 0
        } else {
            throw VictronAdvertisementError.notVictron
        }

        let payloadLength = bytes.count - payloadStart
        guard payloadLength >= minimumPayloadLength else {
            throw VictronAdvertisementError.malformed(
                "Victron manufacturer payload shorter than \(minimumPayloadLength) bytes"
            )
        }

        let payload = Array(bytes[payloadStart...])
        guard payload[0] == productAdvertisementRecordType else {
            throw VictronAdvertisementError.notVictron
        }

        guard payload.count > minimumPayloadLength else {
            throw VictronAdvertisementError.malformed("Victron encrypted payload is empty")
        }

        // OPEN QUESTION: Victron payload byte 1 is observed as 0x02 with Product
        // Advertisement 0x10, but the available sources do not name it.
        let prefix = payload[1]
        let productIDRaw = UInt16(payload[2]) | (UInt16(payload[3]) << 8)
        let nonce = UInt16(payload[5]) | (UInt16(payload[6]) << 8)
        let encryptedPayload = Data(payload.dropFirst(minimumPayloadLength))

        return VictronAdvertisement(
            productAdvertisementPrefix: prefix,
            productID: ProductID(rawValue: productIDRaw),
            recordType: payload[4],
            nonce: nonce,
            encryptionKeyFirstByte: payload[7],
            encryptedPayload: encryptedPayload,
            includesCompanyID: payloadStart == 2
        )
    }
}
