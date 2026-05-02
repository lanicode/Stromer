import Foundation
@testable import StromerScanner
import SwiftData
import XCTest

@MainActor
final class HistoryViewModelTests: XCTestCase {
    func testDailyYieldAggregationIsSortedAndSummedAcrossDevices() {
        let base = Date(timeIntervalSince1970: 1_720_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = calendar.startOfDay(for: base)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!

        let rows = [
            makeDaily(dayStart: secondDay, familyKind: "solar", yieldTodayMax: 400),
            makeDaily(dayStart: firstDay, familyKind: "solar", yieldTodayMax: 300),
            makeDaily(dayStart: firstDay, familyKind: "solar", yieldTodayMax: 200)
        ]

        let points = HistoryViewModel.aggregateDailyYields(rows, calendar: calendar)

        XCTAssertEqual(points.map(\.date), [firstDay, secondDay])
        XCTAssertEqual(points.map(\.yieldWh), [500, 400])
    }

    func testPercentComparisonHandlesZeroPreviousValue() {
        XCTAssertNil(HistoryViewModel.percentChange(current: 100, previous: 0))
        XCTAssertEqual(HistoryViewModel.percentChange(current: 120, previous: 100), 20)
        XCTAssertEqual(HistoryViewModel.percentChange(current: 80, previous: 100), -20)
    }

    func testBatterySocRangeAggregationFindsLowestDay() async throws {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let store = try makeHistoryStore(now: { now })
        let batteryID = UUID()
        store.context.insert(makeDaily(
            deviceID: batteryID,
            dayStart: yesterday,
            familyKind: "battery",
            socMin: 58,
            socMax: 91,
            socAvg: 74,
            fullCharges: 1
        ))
        store.context.insert(makeDaily(
            deviceID: batteryID,
            dayStart: today,
            familyKind: "battery",
            socMin: 64,
            socMax: 92,
            socAvg: 80,
            fullCharges: 0
        ))
        try store.context.save()

        let model = HistoryViewModel(
            historyStore: store,
            registeredDevicesProvider: { [makeRegisteredDevice(id: batteryID, recordType: 0x02)] },
            calendar: calendar,
            nowProvider: { now }
        )

        await model.refresh()

        XCTAssertEqual(model.batterySocRange.count, 2)
        XCTAssertEqual(model.lowestSocDay?.min, 58)
        XCTAssertEqual(model.totalFullCharges, 1)
        XCTAssertTrue(model.hasBatterySection)
    }

    func testDcDcChargingAggregationComputesTotalHours() async throws {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let store = try makeHistoryStore(now: { now })
        let dcDcID = UUID()
        store.context.insert(makeDaily(
            deviceID: dcDcID,
            dayStart: today,
            familyKind: "dcdc",
            chargingMinutes: 90
        ))
        try store.context.save()

        let model = HistoryViewModel(
            historyStore: store,
            registeredDevicesProvider: { [makeRegisteredDevice(id: dcDcID, recordType: 0x04)] },
            calendar: calendar,
            nowProvider: { now }
        )

        await model.refresh()

        XCTAssertEqual(model.dcDcChargingData.first?.minutes, 90)
        XCTAssertEqual(model.totalChargingHours, 1.5)
        XCTAssertTrue(model.hasDcDcSection)
    }

    func testRefreshBuildsSolarComparison() async throws {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let previousWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        let store = try makeHistoryStore(now: { now })
        let solarID = UUID()
        store.context.insert(makeDaily(deviceID: solarID, dayStart: previousWeek, familyKind: "solar", yieldTodayMax: 500))
        store.context.insert(makeDaily(deviceID: solarID, dayStart: today, familyKind: "solar", yieldTodayMax: 1_000))
        try store.context.save()

        let model = HistoryViewModel(
            historyStore: store,
            registeredDevicesProvider: { [makeRegisteredDevice(id: solarID, recordType: 0x01)] },
            calendar: calendar,
            nowProvider: { now }
        )

        await model.refresh()

        XCTAssertEqual(model.totalSolarKwh, 1)
        XCTAssertEqual(model.bestSolarDay?.yieldWh, 1_000)
        XCTAssertEqual(model.weekComparison?.percentChange, 100)
        XCTAssertTrue(model.hasSolarSection)
    }

    func testNoDevicesClearsSections() async {
        let model = HistoryViewModel(
            historyStore: nil,
            registeredDevicesProvider: { [] }
        )

        await model.refresh()

        XCTAssertFalse(model.hasDevices)
        XCTAssertFalse(model.hasSolarSection)
        XCTAssertFalse(model.hasBatterySection)
        XCTAssertFalse(model.hasDcDcSection)
    }
}
