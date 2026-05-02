import SwiftData
import XCTest

@MainActor
final class AggregationTests: XCTestCase {
    func testLiveReadingsAggregateIntoFiveMinuteMinuteAggregate() async throws {
        let now = Date(timeIntervalSince1970: 200_000)
        let store = try makeHistoryStore(now: { now })
        let deviceID = UUID()
        let old = now.addingTimeInterval(-25 * 60 * 60)

        let first = LiveReading(reading: makeBatteryReading(deviceID: deviceID, timestamp: old, soc: 80, voltage: 12.4))
        let second = LiveReading(reading: makeBatteryReading(deviceID: deviceID, timestamp: old.addingTimeInterval(60), soc: 84, voltage: 12.8))
        store.context.insert(first)
        store.context.insert(second)
        try store.context.save()

        await store.aggregateLiveToMinute()

        let minutes = try store.context.fetch(FetchDescriptor<MinuteAggregate>())
        let liveRows = try store.context.fetch(FetchDescriptor<LiveReading>())

        XCTAssertEqual(minutes.count, 1)
        XCTAssertEqual(minutes.first?.sampleCount, 2)
        XCTAssertEqual(minutes.first?.socMin, 80)
        XCTAssertEqual(minutes.first?.socMax, 84)
        XCTAssertEqual(try XCTUnwrap(minutes.first?.voltageAvg), 12.6, accuracy: 0.0001)
        XCTAssertTrue(liveRows.isEmpty)
    }

    func testMinuteAggregatesAggregateIntoDailyAggregate() async throws {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let store = try makeHistoryStore(now: { now })
        let deviceID = UUID()
        let old = now.addingTimeInterval(-31 * 24 * 60 * 60)

        let minute = MinuteAggregate(deviceID: deviceID, slotStart: old, familyKind: "solar", sampleCount: 4)
        minute.pvPowerMax = 320
        minute.pvPowerAvg = 220
        minute.yieldTodayMax = 1_250
        store.context.insert(minute)
        try store.context.save()

        await store.aggregateMinuteToDaily()

        let dailyRows = try store.context.fetch(FetchDescriptor<DailyAggregate>())

        XCTAssertEqual(dailyRows.count, 1)
        XCTAssertEqual(dailyRows.first?.yieldTodayMax, 1_250)
        XCTAssertEqual(dailyRows.first?.peakPvPower, 320)
        XCTAssertEqual(dailyRows.first?.sampleCount, 4)
        XCTAssertEqual(dailyRows.first?.observedMinutes, 5)
    }

    func testLiveRetentionDeletesAggregatedLiveReadings() async throws {
        let now = Date(timeIntervalSince1970: 200_000)
        let store = try makeHistoryStore(now: { now })
        let old = now.addingTimeInterval(-25 * 60 * 60)

        store.context.insert(LiveReading(reading: makeDcDcReading(timestamp: old, outputVoltage: 14.1)))
        try store.context.save()

        await store.aggregateLiveToMinute()

        XCTAssertTrue(try store.context.fetch(FetchDescriptor<LiveReading>()).isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<MinuteAggregate>()).count, 1)
    }

    func testMinuteRetentionDeletesAggregatedMinuteRows() async throws {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let store = try makeHistoryStore(now: { now })
        let old = now.addingTimeInterval(-31 * 24 * 60 * 60)

        let minute = MinuteAggregate(deviceID: UUID(), slotStart: old, familyKind: "dcdc", sampleCount: 1)
        minute.outputVoltageMin = 14.1
        minute.outputVoltageMax = 14.4
        minute.outputVoltageAvg = 14.25
        store.context.insert(minute)
        try store.context.save()

        await store.aggregateMinuteToDaily()

        XCTAssertTrue(try store.context.fetch(FetchDescriptor<MinuteAggregate>()).isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<DailyAggregate>()).count, 1)
    }
}
