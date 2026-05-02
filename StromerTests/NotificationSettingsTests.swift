import XCTest

@MainActor
final class NotificationSettingsTests: XCTestCase {
    func testDefaultValuesAreSensible() {
        let settings = NotificationSettings(userDefaults: makeDefaults())

        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertTrue(settings.thresholdNotificationsEnabled)
        XCTAssertTrue(settings.eventNotificationsEnabled)
        XCTAssertTrue(settings.deviceLossNotificationsEnabled)
        XCTAssertFalse(settings.dailyInsightEnabled)
        XCTAssertTrue(settings.dailyInsightUseSunset)
        XCTAssertEqual(settings.dailyInsightFixedTime.hour, 21)
        XCTAssertEqual(settings.dailyInsightFixedTime.minute, 0)
        XCTAssertEqual(settings.deviceLossThresholdHours, 6)
    }

    func testMasterToggleDisablesThresholdLookupFunctionally() {
        let settings = NotificationSettings(userDefaults: makeDefaults())
        let deviceID = UUID()

        settings.setThreshold(50, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)
        settings.notificationsEnabled = false

        XCTAssertNil(settings.threshold(for: deviceID, type: .socLow))

        settings.notificationsEnabled = true
        XCTAssertEqual(settings.threshold(for: deviceID, type: .socLow), 50)
    }

    func testThresholdsCanBeSetAndReadPerDevice() {
        let settings = NotificationSettings(userDefaults: makeDefaults())
        let firstDeviceID = UUID()
        let secondDeviceID = UUID()

        settings.notificationsEnabled = true
        settings.setThreshold(42, for: firstDeviceID, type: .socLow)
        settings.setThreshold(12.2, for: secondDeviceID, type: .voltageLow)
        settings.setThresholdEnabled(true, for: firstDeviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: secondDeviceID, type: .voltageLow)

        XCTAssertEqual(settings.threshold(for: firstDeviceID, type: .socLow), 42)
        XCTAssertEqual(settings.threshold(for: secondDeviceID, type: .voltageLow), 12.2)
        XCTAssertNil(settings.threshold(for: firstDeviceID, type: .voltageLow))
    }

    func testPersistenceLifecycleUsesUserDefaults() {
        let defaults = makeDefaults()
        let first = NotificationSettings(userDefaults: defaults)
        first.notificationsEnabled = true
        first.dailyInsightEnabled = true
        first.dailyInsightUseSunset = false
        first.dailyInsightFixedTime = DateComponents(hour: 20, minute: 15)
        first.deviceLossThresholdHours = 12

        let second = NotificationSettings(userDefaults: defaults)

        XCTAssertTrue(second.notificationsEnabled)
        XCTAssertTrue(second.dailyInsightEnabled)
        XCTAssertFalse(second.dailyInsightUseSunset)
        XCTAssertEqual(second.dailyInsightFixedTime.hour, 20)
        XCTAssertEqual(second.dailyInsightFixedTime.minute, 15)
        XCTAssertEqual(second.deviceLossThresholdHours, 12)
    }

    func testResetRestoresDefaults() {
        let settings = NotificationSettings(userDefaults: makeDefaults())
        let deviceID = UUID()
        settings.notificationsEnabled = true
        settings.dailyInsightEnabled = true
        settings.deviceLossThresholdHours = 24
        settings.setThreshold(44, for: deviceID, type: .socLow)
        settings.setThresholdEnabled(true, for: deviceID, type: .socLow)

        settings.reset()

        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertFalse(settings.dailyInsightEnabled)
        XCTAssertEqual(settings.deviceLossThresholdHours, 6)
        XCTAssertNil(settings.threshold(for: deviceID, type: .socLow))
        XCTAssertFalse(settings.isThresholdEnabled(for: deviceID, type: .socLow))
    }
}

func makeDefaults() -> UserDefaults {
    let name = "stromer.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
