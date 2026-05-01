import Foundation

public struct DiscoveryHeader: Equatable, Sendable {
    public let productID: UInt16
    public let recordType: UInt8
    public let nonce: UInt16
    public let keyCheckByte: UInt8
    public let hasCompanyIdentifier: Bool
    public let encryptedPayloadLength: Int

    public init(
        productID: UInt16,
        recordType: UInt8,
        nonce: UInt16,
        keyCheckByte: UInt8,
        hasCompanyIdentifier: Bool,
        encryptedPayloadLength: Int
    ) {
        self.productID = productID
        self.recordType = recordType
        self.nonce = nonce
        self.keyCheckByte = keyCheckByte
        self.hasCompanyIdentifier = hasCompanyIdentifier
        self.encryptedPayloadLength = encryptedPayloadLength
    }
}

public enum DiscoveryHeaderParser {
    public static func parseHeader(manufacturerData: Data) -> DiscoveryHeader? {
        let bytes = [UInt8](manufacturerData)
        let payloadOffset: Int

        if bytes.count >= 3,
           bytes[0] == 0xE1,
           bytes[1] == 0x02 {
            payloadOffset = 2
        } else {
            payloadOffset = 0
        }

        guard bytes.count >= payloadOffset + 8 else {
            return nil
        }

        guard bytes[payloadOffset] == 0x10 else {
            return nil
        }

        guard bytes[payloadOffset + 1] == 0x02 else {
            return nil
        }

        let productID = UInt16(bytes[payloadOffset + 2])
            | (UInt16(bytes[payloadOffset + 3]) << 8)
        let nonce = UInt16(bytes[payloadOffset + 5])
            | (UInt16(bytes[payloadOffset + 6]) << 8)

        return DiscoveryHeader(
            productID: productID,
            recordType: bytes[payloadOffset + 4],
            nonce: nonce,
            keyCheckByte: bytes[payloadOffset + 7],
            hasCompanyIdentifier: payloadOffset == 2,
            encryptedPayloadLength: max(0, bytes.count - payloadOffset - 8)
        )
    }
}
