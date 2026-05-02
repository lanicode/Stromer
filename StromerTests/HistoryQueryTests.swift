import SwiftData
import XCTest

@MainActor
final class HistoryQueryTests: XCTestCase {
    func testLiveReadingsReturnRowsInRequestedRangeSortedByTimestamp() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 10_000)

        store.context.insert(LiveReading(reading: makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(30), soc: 81)))
        store.context.insert(LiveReading(reading: makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(10), soc: 80)))
        store.context.insert(LiveReading(reading: makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(90), soc: 82)))
        try store.context.save()

        let rows = await store.liveReadings(
            deviceID: deviceID,
            from: start,
            to: start.addingTimeInterval(60)
        )

        XCTAssertEqual(rows.map(\.soc), [80, 81])
        XCTAssertEqual(rows.map(\.timestamp), rows.map(\.timestamp).sorted())
    }

    func testLiveReadingsFilterByDeviceID() async throws {
        let store = try makeHistoryStore()
        let targetID = UUID()
        let otherID = UUID()
        let timestamp = Date(timeIntervalSince1970: 10_000)

        store.context.insert(LiveReading(reading: makeBatteryReading(deviceID: targetID, timestamp: timestamp, soc: 75)))
        store.context.insert(LiveReading(reading: makeBatteryReading(deviceID: otherID, timestamp: timestamp, soc: 99)))
        try store.context.save()

        let rows = await store.liveReadings(
            deviceID: targetID,
            from: timestamp.addingTimeInterval(-10),
            to: timestamp.addingTimeInterval(10)
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.deviceID, targetID)
        XCTAssertEqual(rows.first?.soc, 75)
    }

    func testLiveReadingsReturnEmptyResultWhenNoRowsMatch() async throws {
        let store = try makeHistoryStore()
        let timestamp = Date(timeIntervalSince1970: 10_000)

        store.context.insert(LiveReading(reading: makeBatteryReading(timestamp: timestamp, soc: 75)))
        try store.context.save()

        let rows = await store.liveReadings(
            deviceID: UUID(),
            from: timestamp.addingTimeInterval(-10),
            to: timestamp.addingTimeInterval(10)
        )

        XCTAssertTrue(rows.isEmpty)
    }

    func testMinuteAggregatesReturnRequestedDeviceAndRangeSorted() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let otherID = UUID()
        let start = Date(timeIntervalSince1970: 20_000)

        store.context.insert(makeMinute(deviceID: deviceID, slotStart: start.addingTimeInterval(300), socAvg: 82))
        store.context.insert(makeMinute(deviceID: deviceID, slotStart: start, socAvg: 80))
        store.context.insert(makeMinute(deviceID: otherID, slotStart: start, socAvg: 99))
        try store.context.save()

        let rows = await store.minuteAggregates(
            deviceID: deviceID,
            from: start.addingTimeInterval(-1),
            to: start.addingTimeInterval(301)
        )

        XCTAssertEqual(rows.map(\.socAvg), [80, 82])
        XCTAssertEqual(rows.map(\.slotStart), rows.map(\.slotStart).sorted())
    }

    func testDailyAggregatesAndTodayAggregateUseDayStart() async throws {
        let now = Date(timeIntervalSince1970: 80_000)
        let store = try makeHistoryStore(now: { now })
        let deviceID = UUID()
        let today = Calendar.current.startOfDay(for: now)
        let yesterday = today.addingTimeInterval(-24 * 60 * 60)

        let oldDaily = DailyAggregate(deviceID: deviceID, dayStart: yesterday, familyKind: "solar")
        oldDaily.yieldTodayMax = 400
        let todayDaily = DailyAggregate(deviceID: deviceID, dayStart: today, familyKind: "solar")
        todayDaily.yieldTodayMax = 900
        store.context.insert(todayDaily)
        store.context.insert(oldDaily)
        try store.context.save()

        let rows = await store.dailyAggregates(
            deviceID: deviceID,
            from: yesterday,
            to: today
        )
        let fetchedToday = await store.todayAggregate(deviceID: deviceID)

        XCTAssertEqual(rows.map(\.yieldTodayMax), [400, 900])
        XCTAssertEqual(fetchedToday?.yieldTodayMax, 900)
    }

    private func makeMinute(
        deviceID: UUID,
        slotStart: Date,
        socAvg: Double
    ) -> MinuteAggregate {
        let minute = MinuteAggregate(
            deviceID: deviceID,
            slotStart: slotStart,
            familyKind: "battery",
            sampleCount: 1
        )
        minute.socAvg = socAvg
        return minute
    }
}
