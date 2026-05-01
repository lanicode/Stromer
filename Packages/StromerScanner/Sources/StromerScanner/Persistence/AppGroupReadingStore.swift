import Foundation

public protocol AppGroupKeyValueStoring: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
}

public final class UserDefaultsKeyValueStore: AppGroupKeyValueStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(suiteName: String = StromerIdentifiers.appGroup) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw ScannerError.appGroupUnavailable(suiteName)
        }
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ value: Data?, forKey key: String) {
        defaults.set(value, forKey: key)
        _ = defaults.synchronize()
    }
}

public final class AppGroupReadingStore: ReadingStoring, @unchecked Sendable {
    private let backing: AppGroupKeyValueStoring
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init(
        suiteName: String = StromerIdentifiers.appGroup,
        key: String = StromerIdentifiers.latestReadingsStoreKey
    ) throws {
        try self.init(
            backing: UserDefaultsKeyValueStore(suiteName: suiteName),
            key: key
        )
    }

    public init(
        backing: AppGroupKeyValueStoring,
        key: String = StromerIdentifiers.latestReadingsStoreKey
    ) {
        self.backing = backing
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func saveReadings(_ readings: [DeviceReading]) throws {
        let data = try encoder.encode(readings.sorted { $0.deviceID.uuidString < $1.deviceID.uuidString })
        backing.set(data, forKey: key)
    }

    public func loadReadings() throws -> [DeviceReading] {
        guard let data = backing.data(forKey: key) else {
            return []
        }
        return try decoder.decode([DeviceReading].self, from: data)
    }

    public func deleteReading(deviceID: UUID) throws {
        let remaining = try loadReadings().filter { $0.deviceID != deviceID }
        try saveReadings(remaining)
    }
}
