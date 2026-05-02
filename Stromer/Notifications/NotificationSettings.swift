import Foundation
import Observation

@Observable
final class NotificationSettings {
    static let keyPrefix = "stromer.notifications."

    var notificationsEnabled: Bool {
        didSet { save() }
    }
    var thresholdNotificationsEnabled: Bool {
        didSet { save() }
    }
    var eventNotificationsEnabled: Bool {
        didSet { save() }
    }
    var deviceLossNotificationsEnabled: Bool {
        didSet { save() }
    }
    var dailyInsightEnabled: Bool {
        didSet { save() }
    }
    var dailyInsightUseSunset: Bool {
        didSet { save() }
    }
    var dailyInsightFixedTime: DateComponents {
        didSet { save() }
    }
    var deviceLossThresholdHours: Int {
        didSet {
            let clamped = Self.clampedDeviceLossThresholdHours(deviceLossThresholdHours)
            if clamped != deviceLossThresholdHours {
                deviceLossThresholdHours = clamped
            } else {
                save()
            }
        }
    }
    var thresholds: [String: Double] {
        didSet { save() }
    }
    var thresholdsEnabled: [String: Bool] {
        didSet { save() }
    }

    static let defaults: [String: Double] = [
        ThresholdType.socLow.rawValue: 30,
        ThresholdType.socHigh.rawValue: 99,
        ThresholdType.voltageLow.rawValue: 11.8,
        ThresholdType.voltageHigh.rawValue: 15,
        ThresholdType.temperatureHigh.rawValue: 50,
        ThresholdType.pvPowerPeak.rawValue: 200,
        ThresholdType.dcDcOutputLow.rawValue: 12
    ]

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        notificationsEnabled = userDefaults.object(
            forKey: Self.storageKey("notificationsEnabled")
        ) as? Bool ?? false
        thresholdNotificationsEnabled = userDefaults.object(
            forKey: Self.storageKey("thresholdNotificationsEnabled")
        ) as? Bool ?? true
        eventNotificationsEnabled = userDefaults.object(
            forKey: Self.storageKey("eventNotificationsEnabled")
        ) as? Bool ?? true
        deviceLossNotificationsEnabled = userDefaults.object(
            forKey: Self.storageKey("deviceLossNotificationsEnabled")
        ) as? Bool ?? true
        dailyInsightEnabled = userDefaults.object(
            forKey: Self.storageKey("dailyInsightEnabled")
        ) as? Bool ?? false
        dailyInsightUseSunset = userDefaults.object(
            forKey: Self.storageKey("dailyInsightUseSunset")
        ) as? Bool ?? true

        let fixedHour = userDefaults.object(
            forKey: Self.storageKey("dailyInsightFixedHour")
        ) as? Int ?? 21
        let fixedMinute = userDefaults.object(
            forKey: Self.storageKey("dailyInsightFixedMinute")
        ) as? Int ?? 0
        dailyInsightFixedTime = DateComponents(hour: fixedHour, minute: fixedMinute)

        let lossHours = userDefaults.object(
            forKey: Self.storageKey("deviceLossThresholdHours")
        ) as? Int ?? 6
        deviceLossThresholdHours = Self.clampedDeviceLossThresholdHours(lossHours)
        thresholds = userDefaults.dictionary(
            forKey: Self.storageKey("thresholds")
        ) as? [String: Double] ?? [:]
        thresholdsEnabled = userDefaults.dictionary(
            forKey: Self.storageKey("thresholdsEnabled")
        ) as? [String: Bool] ?? [:]
    }

    func save() {
        userDefaults.set(notificationsEnabled, forKey: Self.storageKey("notificationsEnabled"))
        userDefaults.set(thresholdNotificationsEnabled, forKey: Self.storageKey("thresholdNotificationsEnabled"))
        userDefaults.set(eventNotificationsEnabled, forKey: Self.storageKey("eventNotificationsEnabled"))
        userDefaults.set(deviceLossNotificationsEnabled, forKey: Self.storageKey("deviceLossNotificationsEnabled"))
        userDefaults.set(dailyInsightEnabled, forKey: Self.storageKey("dailyInsightEnabled"))
        userDefaults.set(dailyInsightUseSunset, forKey: Self.storageKey("dailyInsightUseSunset"))
        userDefaults.set(dailyInsightFixedTime.hour ?? 21, forKey: Self.storageKey("dailyInsightFixedHour"))
        userDefaults.set(dailyInsightFixedTime.minute ?? 0, forKey: Self.storageKey("dailyInsightFixedMinute"))
        userDefaults.set(deviceLossThresholdHours, forKey: Self.storageKey("deviceLossThresholdHours"))
        userDefaults.set(thresholds, forKey: Self.storageKey("thresholds"))
        userDefaults.set(thresholdsEnabled, forKey: Self.storageKey("thresholdsEnabled"))
    }

    func reset() {
        notificationsEnabled = false
        thresholdNotificationsEnabled = true
        eventNotificationsEnabled = true
        deviceLossNotificationsEnabled = true
        dailyInsightEnabled = false
        dailyInsightUseSunset = true
        dailyInsightFixedTime = DateComponents(hour: 21, minute: 0)
        deviceLossThresholdHours = 6
        thresholds = [:]
        thresholdsEnabled = [:]
        save()
    }

    func threshold(for deviceID: UUID, type: ThresholdType) -> Double? {
        guard notificationsEnabled, thresholdNotificationsEnabled else {
            return nil
        }

        let key = thresholdKey(for: deviceID, type: type)
        guard thresholdsEnabled[key] == true else {
            return nil
        }

        return thresholds[key] ?? Self.defaults[type.rawValue]
    }

    func storedThreshold(for deviceID: UUID, type: ThresholdType) -> Double {
        let key = thresholdKey(for: deviceID, type: type)
        return thresholds[key] ?? Self.defaults[type.rawValue] ?? 0
    }

    func isThresholdEnabled(for deviceID: UUID, type: ThresholdType) -> Bool {
        thresholdsEnabled[thresholdKey(for: deviceID, type: type)] == true
    }

    func setThreshold(_ value: Double, for deviceID: UUID, type: ThresholdType) {
        thresholds[thresholdKey(for: deviceID, type: type)] = value
    }

    func setThresholdEnabled(_ isEnabled: Bool, for deviceID: UUID, type: ThresholdType) {
        thresholdsEnabled[thresholdKey(for: deviceID, type: type)] = isEnabled
    }

    func thresholdKey(for deviceID: UUID, type: ThresholdType) -> String {
        "\(deviceID.uuidString)-\(type.rawValue)"
    }

    static func storageKey(_ name: String) -> String {
        "\(keyPrefix)\(name)"
    }

    private static func clampedDeviceLossThresholdHours(_ value: Int) -> Int {
        min(max(value, 1), 24)
    }

    enum ThresholdType: String, CaseIterable, Identifiable {
        case socLow = "soc-low"
        case socHigh = "soc-high"
        case voltageLow = "voltage-low"
        case voltageHigh = "voltage-high"
        case temperatureHigh = "temperature-high"
        case pvPowerPeak = "pvpower-peak"
        case dcDcOutputLow = "dcdc-output-low"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .socLow:
                return "Tiefentladung"
            case .socHigh:
                return "Volladung"
            case .voltageLow:
                return "Spannung niedrig"
            case .voltageHigh:
                return "Spannung hoch"
            case .temperatureHigh:
                return "Temperatur hoch"
            case .pvPowerPeak:
                return "Solar-Peak"
            case .dcDcOutputLow:
                return "Ausgang niedrig"
            }
        }

        var unit: String {
            switch self {
            case .socLow, .socHigh:
                return "%"
            case .voltageLow, .voltageHigh, .dcDcOutputLow:
                return "V"
            case .temperatureHigh:
                return "°C"
            case .pvPowerPeak:
                return "W"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .socLow:
                return 5...80
            case .socHigh:
                return 80...100
            case .voltageLow, .dcDcOutputLow:
                return 9...14
            case .voltageHigh:
                return 13...16
            case .temperatureHigh:
                return 30...80
            case .pvPowerPeak:
                return 50...1_500
            }
        }

        var step: Double {
            switch self {
            case .socLow, .socHigh, .temperatureHigh, .pvPowerPeak:
                return 1
            case .voltageLow, .voltageHigh, .dcDcOutputLow:
                return 0.1
            }
        }
    }
}
