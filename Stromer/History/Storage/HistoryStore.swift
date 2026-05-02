import Foundation
import StromerScanner

@MainActor
protocol HistoryStore: Sendable {
    func recordReading(_ reading: DeviceReading) async
    func aggregateLiveToMinute() async
    func aggregateMinuteToDaily() async
    func currentStorageSize() async -> Int64
    func deleteHistoryOlderThan(_ date: Date) async

    func liveReadings(deviceID: UUID, from: Date, to: Date) async -> [LiveReading]
    func minuteAggregates(deviceID: UUID, from: Date, to: Date) async -> [MinuteAggregate]
    func dailyAggregates(deviceID: UUID, from: Date, to: Date) async -> [DailyAggregate]
    func todayAggregate(deviceID: UUID) async -> DailyAggregate?
}
