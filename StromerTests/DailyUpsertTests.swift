import SwiftData
import XCTest

@MainActor
final class DailyUpsertTests: XCTestCase {
    func testYieldTodayMaxUsesHighestReadingInSameDay() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 50_000)

        await store.recordReading(makeSolarReading(deviceID: deviceID, timestamp: start, yieldToday: 100))
        await store.recordReading(makeSolarReading(deviceID: deviceID, timestamp: start.addingTimeInterval(2), yieldToday: 450))
        await store.recordReading(makeSolarReading(deviceID: deviceID, timestamp: start.addingTimeInterval(4), yieldToday: 300))

        let daily = try XCTUnwrap(store.context.fetch(FetchDescriptor<DailyAggregate>()).first)

        XCTAssertEqual(daily.yieldTodayMax, 450)
        XCTAssertEqual(daily.peakPvPower, 250)
        XCTAssertEqual(daily.sampleCount, 3)
    }

    func testDayChangeCreatesNewDailyAggregate() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 50_000))
        let secondDay = firstDay.addingTimeInterval(25 * 60 * 60)

        await store.recordReading(makeSolarReading(deviceID: deviceID, timestamp: firstDay, yieldToday: 900))
        await store.recordReading(makeSolarReading(deviceID: deviceID, timestamp: secondDay, yieldToday: 40))

        let dailyRows = try store.context.fetch(FetchDescriptor<DailyAggregate>())

        XCTAssertEqual(dailyRows.count, 2)
        XCTAssertEqual(dailyRows.compactMap(\.yieldTodayMax).sorted(), [40, 900])
    }

    func testBatterySocMinMaxIsTracked() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 50_000)

        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start, soc: 72))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(2), soc: 88))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(4), soc: 66))

        let daily = try XCTUnwrap(store.context.fetch(FetchDescriptor<DailyAggregate>()).first)

        XCTAssertEqual(daily.socMin, 66)
        XCTAssertEqual(daily.socMax, 88)
        XCTAssertEqual(try XCTUnwrap(daily.socAvg), (72 + 88 + 66) / 3, accuracy: 0.0001)
    }

    func testDcDcVoltageMinMaxAndOffReasonAreTracked() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 50_000)

        await store.recordReading(makeDcDcReading(deviceID: deviceID, timestamp: start, inputVoltage: 12.9, outputVoltage: 14.1))
        await store.recordReading(makeDcDcReading(deviceID: deviceID, timestamp: start.addingTimeInterval(2), inputVoltage: 13.2, outputVoltage: 14.5))

        let daily = try XCTUnwrap(store.context.fetch(FetchDescriptor<DailyAggregate>()).first)

        XCTAssertEqual(daily.inputVoltageMin, 12.9)
        XCTAssertEqual(daily.inputVoltageMax, 13.2)
        XCTAssertEqual(daily.outputVoltageMin, 14.1)
        XCTAssertEqual(daily.outputVoltageMax, 14.5)
        XCTAssertEqual(daily.offReasonLastRaw, 0)
    }

    func testDailyGapAndObservedMinutesAreTrackedAcrossLargePause() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 50_000)

        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(60)))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(32 * 60)))

        let daily = try XCTUnwrap(store.context.fetch(FetchDescriptor<DailyAggregate>()).first)

        XCTAssertEqual(daily.gapCount, 1)
        XCTAssertEqual(daily.observedMinutes, 1, accuracy: 0.0001)
    }
}
