import Foundation
@testable import StromerScanner
import UserNotifications
import XCTest

@MainActor
final class NotificationCoordinatorTests: XCTestCase {
    func testThresholdHysteresisFiresOnlyOnCrossing() async {
        let deviceID = UUID()
        let (coordinator, center, settings) = makeCoordinator(cooldown: 0)
        settings.setThreshold(50, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)

        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 60))
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 40))
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 39))
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 55))
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 45))

        XCTAssertEqual(center.requests.count, 2)
        XCTAssertEqual(center.requests.first?.content.title, "Tiefentladung-Warnung")
    }

    func testThrottlingSuppressesSecondNotificationWithinOneHour() async {
        let deviceID = UUID()
        var now = Date(timeIntervalSince1970: 10_000)
        let (coordinator, center, settings) = makeCoordinator(now: { now })
        settings.setThreshold(50, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)

        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: now, soc: 40))
        now = now.addingTimeInterval(60)
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: now, soc: 60))
        now = now.addingTimeInterval(60)
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: now, soc: 40))

        XCTAssertEqual(center.requests.count, 1)
    }

    func testMasterToggleOffSuppressesNotifications() async {
        let deviceID = UUID()
        let (coordinator, center, settings) = makeCoordinator()
        settings.notificationsEnabled = false
        settings.setThreshold(50, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)

        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 40))

        XCTAssertTrue(center.requests.isEmpty)
    }

    func testThresholdToggleOffSuppressesThresholdNotifications() async {
        let deviceID = UUID()
        let (coordinator, center, settings) = makeCoordinator()
        settings.thresholdNotificationsEnabled = false
        settings.setThreshold(50, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)

        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 40))

        XCTAssertTrue(center.requests.isEmpty)
    }

    func testFullChargeDetectionAfterLowerSoc() async {
        let deviceID = UUID()
        let (coordinator, center, _) = makeCoordinator(cooldown: 0)

        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 80))
        await coordinator.evaluate(reading: makeBatteryReading(deviceID: deviceID, timestamp: Date(), soc: 99))

        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.first?.content.title, "Batterie voll")
    }

    func testChargerStateChangeDetection() async {
        let deviceID = UUID()
        let (coordinator, center, _) = makeCoordinator(cooldown: 0)

        await coordinator.evaluate(reading: makeSolarReading(deviceID: deviceID, timestamp: Date(), pvPower: 80))
        await coordinator.evaluate(reading: makeSolarReading(deviceID: deviceID, timestamp: Date(), pvPower: 120))
        await coordinator.evaluate(reading: makeSolarReading(deviceID: deviceID, timestamp: Date(), pvPower: 120))

        XCTAssertTrue(center.requests.isEmpty)

        let changed = DeviceReading(
            deviceID: deviceID,
            name: "Roof Solar",
            localName: "SmartSolar",
            peripheralID: UUID(),
            productID: 0xA057,
            recordType: 0x01,
            modelName: "SmartSolar MPPT",
            rssi: -70,
            timestamp: Date(),
            freshness: DeviceFreshness(lastSeenAt: Date(), now: Date()),
            payload: .solarCharger(SolarChargerReading(
                deviceStateRaw: 5,
                chargerErrorCode: nil,
                batteryVoltage: 13.91,
                batteryCurrent: 18.4,
                yieldTodayWh: 850,
                pvPower: 120,
                loadCurrent: 0.4
            ))
        )
        await coordinator.evaluate(reading: changed)

        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.first?.content.title, "Ladezustand geändert")
    }

    func testDeviceLossFiresWhenLatestReadingIsOlderThanThreshold() async {
        let deviceID = UUID()
        let now = Date(timeIntervalSince1970: 20_000)
        let (coordinator, center, settings) = makeCoordinator(now: { now })
        settings.deviceLossThresholdHours = 6
        let device = RegisteredDevice(id: deviceID, name: "House Battery", advertisementKey: Data())

        await coordinator.checkDeviceLoss(
            registeredDevices: [device],
            latestReadings: [deviceID: now.addingTimeInterval(-7 * 3_600)]
        )

        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.first?.content.title, "Gerät offline")
    }

    private func makeCoordinator(
        now: @escaping () -> Date = Date.init,
        cooldown: TimeInterval = 3_600
    ) -> (NotificationCoordinator, MockNotificationCenter, NotificationSettings) {
        let settings = NotificationSettings(userDefaults: makeDefaults())
        settings.notificationsEnabled = true
        settings.thresholdNotificationsEnabled = true
        settings.eventNotificationsEnabled = true
        settings.deviceLossNotificationsEnabled = true
        let center = MockNotificationCenter()
        let coordinator = NotificationCoordinator(
            settings: settings,
            center: center,
            nowProvider: now,
            cooldownInterval: cooldown
        )
        return (coordinator, center, settings)
    }
}

@MainActor
final class MockNotificationCenter: LocalNotificationScheduling {
    var requests: [UNNotificationRequest] = []
    var authorizationResult = true

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        requests.removeAll { identifiers.contains($0.identifier) }
    }
}
