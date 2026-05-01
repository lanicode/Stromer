import Foundation

public protocol ReadingStoring: Sendable {
    func saveReadings(_ readings: [DeviceReading]) throws
    func loadReadings() throws -> [DeviceReading]
    func deleteReading(deviceID: UUID) throws
}
