import Foundation

public enum DiscoveryDisplayState: String, Codable, Equatable, Sendable {
    case full
    case dimmed
}

public struct DiscoveredDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { peripheralID }

    public let peripheralID: UUID
    public let localName: String?
    public let productID: UInt16
    public let recordType: UInt8
    public let keyCheckByte: UInt8
    public let estimatedModelName: String
    public let estimatedDeviceType: DiscoveredDeviceType
    public let supportStatus: DiscoverySupportStatus
    public let rssi: Int
    public let lastSeenAt: Date
    public let isRegistered: Bool
    public let displayState: DiscoveryDisplayState
    public let manufacturerData: Data

    public init(
        peripheralID: UUID,
        localName: String?,
        productID: UInt16,
        recordType: UInt8,
        keyCheckByte: UInt8,
        estimatedModelName: String,
        estimatedDeviceType: DiscoveredDeviceType,
        supportStatus: DiscoverySupportStatus,
        rssi: Int,
        lastSeenAt: Date,
        isRegistered: Bool,
        displayState: DiscoveryDisplayState,
        manufacturerData: Data
    ) {
        self.peripheralID = peripheralID
        self.localName = localName
        self.productID = productID
        self.recordType = recordType
        self.keyCheckByte = keyCheckByte
        self.estimatedModelName = estimatedModelName
        self.estimatedDeviceType = estimatedDeviceType
        self.supportStatus = supportStatus
        self.rssi = rssi
        self.lastSeenAt = lastSeenAt
        self.isRegistered = isRegistered
        self.displayState = displayState
        self.manufacturerData = manufacturerData
    }
}
