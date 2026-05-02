import Foundation
@testable import StromerScanner
import SwiftData
import XCTest

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testBatteryPowerUsesSignedCurrent() {
        XCTAssertEqual(DashboardViewModel.batteryPowerWatts(voltage: 12.5, current: -4), -50)
        XCTAssertEqual(DashboardViewModel.batteryPowerWatts(voltage: 13.0, current: 2), 26)
    }

    func testLiveBalanceCombinesSolarAndBatteryPower() {
        let deviceID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let readings = [
            makeSolarReading(deviceID: UUID(), timestamp: now, pvPower: 300, yieldToday: 1_200),
            makeBatteryReading(deviceID: deviceID, timestamp: now, voltage: 12.5, current: 4)
        ]
        let model = DashboardViewModel(
            historyStore: nil,
            registeredDevicesProvider: { [] },
            latestReadingsProvider: { readings },
            sunsetService: nil,
            nowProvider: { now }
        )

        model.refreshLiveValues()

        XCTAssertEqual(model.currentSolarIn, 300)
        XCTAssertEqual(model.currentNet, 50)
        XCTAssertEqual(model.currentLoadOut, 250)
    }

    func testOnlyBatteryEstimatesLoadWithoutSolar() {
        let now = Date(timeIntervalSince1970: 1_000)
        let readings = [
            makeBatteryReading(timestamp: now, voltage: 12, current: -3)
        ]
        let model = DashboardViewModel(
            historyStore: nil,
            registeredDevicesProvider: { [makeRegisteredDevice(recordType: 0x02)] },
            latestReadingsProvider: { readings },
            sunsetService: nil,
            nowProvider: { now }
        )

        model.refreshLiveValues()

        XCTAssertNil(model.currentSolarIn)
        XCTAssertEqual(model.currentNet, -36)
        XCTAssertEqual(model.currentLoadOut, 36)
    }

    func testEmptyDashboardHasNoDevices() async {
        let model = DashboardViewModel(
            historyStore: nil,
            registeredDevicesProvider: { [] },
            latestReadingsProvider: { [] },
            sunsetService: nil
        )

        await model.refresh()

        XCTAssertFalse(model.hasDevices)
        XCTAssertNil(model.todaySolarYield)
        XCTAssertEqual(model.insights.first?.id, "collecting")
    }

    func testSolarTrendAndInsightsUseDailyAggregates() async throws {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let store = try makeHistoryStore(now: { now })
        let solarID = UUID()
        store.context.insert(makeDaily(deviceID: solarID, dayStart: yesterday, familyKind: "solar", yieldTodayMax: 1_000))
        store.context.insert(makeDaily(deviceID: solarID, dayStart: today, familyKind: "solar", yieldTodayMax: 1_250))
        try store.context.save()

        let model = DashboardViewModel(
            historyStore: store,
            registeredDevicesProvider: { [makeRegisteredDevice(id: solarID, recordType: 0x01)] },
            latestReadingsProvider: { [] },
            sunsetService: nil,
            calendar: calendar,
            nowProvider: { now }
        )

        await model.refresh()

        XCTAssertEqual(model.todaySolarYield, 1_250)
        XCTAssertEqual(model.bestDayYield, 1_250)
        XCTAssertTrue(model.insights.contains { $0.id == "solar-comparison" })
    }

    func testConsumptionEstimateIntegratesNegativeBatteryPower() {
        let start = Date(timeIntervalSince1970: 1_000)
        let first = LiveReading(reading: makeBatteryReading(timestamp: start, voltage: 12, current: -10))
        let second = LiveReading(reading: makeBatteryReading(timestamp: start.addingTimeInterval(60), voltage: 12, current: -10))

        let estimate = DashboardViewModel.estimatedConsumptionWh(from: [first, second])

        XCTAssertEqual(estimate, 2, accuracy: 0.001)
    }
}

func makeRegisteredDevice(
    id: UUID = UUID(),
    recordType: UInt8
) -> RegisteredDevice {
    RegisteredDevice(
        id: id,
        name: "Test Device",
        advertisementKey: Data(repeating: 0x01, count: 16),
        recordType: recordType
    )
}

func makeDaily(
    deviceID: UUID = UUID(),
    dayStart: Date,
    familyKind: String,
    yieldTodayMax: Double? = nil,
    socMin: Double? = nil,
    socMax: Double? = nil,
    socAvg: Double? = nil,
    fullCharges: Int? = nil,
    chargingMinutes: Double? = nil
) -> DailyAggregate {
    let daily = DailyAggregate(
        deviceID: deviceID,
        dayStart: dayStart,
        familyKind: familyKind
    )
    daily.yieldTodayMax = yieldTodayMax
    daily.socMin = socMin
    daily.socMax = socMax
    daily.socAvg = socAvg
    daily.fullChargesCount = fullCharges
    daily.totalChargingMinutes = chargingMinutes
    return daily
}
