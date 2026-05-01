import Foundation
import Observation
import VictronParser

@MainActor
@Observable
public final class VictronStore {
    public private(set) var readingsByDeviceID: [UUID: DeviceReading]

    @ObservationIgnored private let readingStore: (any ReadingStoring)?
    @ObservationIgnored private let nowProvider: @Sendable () -> Date

    public init(
        readings: [DeviceReading] = [],
        readingStore: (any ReadingStoring)? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.readingsByDeviceID = Dictionary(
            uniqueKeysWithValues: readings.map { ($0.deviceID, $0) }
        )
        self.readingStore = readingStore
        self.nowProvider = now
    }

    public var latestReadings: [DeviceReading] {
        readingsByDeviceID.values.sorted { $0.name < $1.name }
    }

    public func reading(for deviceID: UUID) -> DeviceReading? {
        readingsByDeviceID[deviceID]
    }

    @discardableResult
    public func update(
        device: RegisteredDevice,
        record: VictronRecord,
        advertisement: RawAdvertisement
    ) throws -> DeviceReading {
        let reading = DeviceReading(
            device: device,
            record: record,
            rssi: advertisement.rssi,
            timestamp: advertisement.timestamp,
            now: nowProvider()
        )
        readingsByDeviceID[device.id] = reading
        try persist()
        return reading
    }

    public func loadPersistedReadings() throws {
        guard let readingStore else {
            return
        }
        readingsByDeviceID = Dictionary(
            uniqueKeysWithValues: try readingStore.loadReadings().map { ($0.deviceID, $0) }
        )
    }

    public func recalculateFreshness(now: Date? = nil) throws {
        let referenceDate = now ?? nowProvider()
        var updatedReadings = readingsByDeviceID

        for (id, reading) in readingsByDeviceID {
            var updated = reading
            updated.freshness = DeviceFreshness(
                lastSeenAt: reading.timestamp,
                now: referenceDate
            )
            updatedReadings[id] = updated
        }

        readingsByDeviceID = updatedReadings
        try persist()
    }

    public func removeReading(deviceID: UUID) throws {
        readingsByDeviceID.removeValue(forKey: deviceID)
        try persist()
    }

    private func persist() throws {
        try readingStore?.saveReadings(latestReadings)
    }
}
