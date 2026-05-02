import Foundation
import StromerScanner

@MainActor
protocol HistoryStore: Sendable {
    func recordReading(_ reading: DeviceReading) async
    func aggregateLiveToMinute() async
    func aggregateMinuteToDaily() async
    func currentStorageSize() async -> Int64
    func deleteHistoryOlderThan(_ date: Date) async
}
