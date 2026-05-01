import Foundation

public struct RegisteredDevice: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var advertisementKey: Data
    public var peripheralID: UUID?
    public var localName: String?
    public var productID: UInt16?
    public var recordType: UInt8?
    public var lastSeenAt: Date?
    public var lastRSSI: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        advertisementKey: Data,
        peripheralID: UUID? = nil,
        localName: String? = nil,
        productID: UInt16? = nil,
        recordType: UInt8? = nil,
        lastSeenAt: Date? = nil,
        lastRSSI: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.advertisementKey = advertisementKey
        self.peripheralID = peripheralID
        self.localName = localName
        self.productID = productID
        self.recordType = recordType
        self.lastSeenAt = lastSeenAt
        self.lastRSSI = lastRSSI
    }
}
