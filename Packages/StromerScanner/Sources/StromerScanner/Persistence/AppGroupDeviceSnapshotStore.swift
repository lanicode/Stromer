import Foundation

public struct RegisteredDeviceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var peripheralID: UUID?
    public var localName: String?
    public var productID: UInt16?
    public var recordType: UInt8?
    public var lastSeenAt: Date?
    public var lastRSSI: Int?

    public init(
        id: UUID,
        name: String,
        peripheralID: UUID? = nil,
        localName: String? = nil,
        productID: UInt16? = nil,
        recordType: UInt8? = nil,
        lastSeenAt: Date? = nil,
        lastRSSI: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.peripheralID = peripheralID
        self.localName = localName
        self.productID = productID
        self.recordType = recordType
        self.lastSeenAt = lastSeenAt
        self.lastRSSI = lastRSSI
    }

    public init(device: RegisteredDevice) {
        self.init(
            id: device.id,
            name: device.name,
            peripheralID: device.peripheralID,
            localName: device.localName,
            productID: device.productID,
            recordType: device.recordType,
            lastSeenAt: device.lastSeenAt,
            lastRSSI: device.lastRSSI
        )
    }

    public func registeredDevice(advertisementKey: Data) -> RegisteredDevice {
        RegisteredDevice(
            id: id,
            name: name,
            advertisementKey: advertisementKey,
            peripheralID: peripheralID,
            localName: localName,
            productID: productID,
            recordType: recordType,
            lastSeenAt: lastSeenAt,
            lastRSSI: lastRSSI
        )
    }
}

public protocol RegisteredDeviceSnapshotStoring: Sendable {
    func saveDeviceSnapshots(_ snapshots: [RegisteredDeviceSnapshot]) throws
    func loadDeviceSnapshots() throws -> [RegisteredDeviceSnapshot]
    func deleteDeviceSnapshot(id: UUID) throws
}

public final class AppGroupDeviceSnapshotStore: RegisteredDeviceSnapshotStoring, @unchecked Sendable {
    private let backing: AppGroupKeyValueStoring
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init(
        suiteName: String = StromerIdentifiers.appGroup,
        key: String = StromerIdentifiers.registeredDevicesStoreKey
    ) throws {
        try self.init(
            backing: UserDefaultsKeyValueStore(suiteName: suiteName),
            key: key
        )
    }

    public init(
        backing: AppGroupKeyValueStoring,
        key: String = StromerIdentifiers.registeredDevicesStoreKey
    ) {
        self.backing = backing
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func saveDeviceSnapshots(_ snapshots: [RegisteredDeviceSnapshot]) throws {
        let sorted = snapshots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let data = try encoder.encode(sorted)
        backing.set(data, forKey: key)
    }

    public func loadDeviceSnapshots() throws -> [RegisteredDeviceSnapshot] {
        guard let data = backing.data(forKey: key) else {
            return []
        }

        return try decoder.decode([RegisteredDeviceSnapshot].self, from: data)
    }

    public func deleteDeviceSnapshot(id: UUID) throws {
        let remaining = try loadDeviceSnapshots().filter { $0.id != id }
        try saveDeviceSnapshots(remaining)
    }
}
