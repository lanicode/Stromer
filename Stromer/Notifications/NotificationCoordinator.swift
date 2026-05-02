import Foundation
import StromerScanner
import UserNotifications

@MainActor
protocol LocalNotificationScheduling: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: LocalNotificationScheduling {}

@MainActor
final class NotificationCoordinator {
    private let settings: NotificationSettings
    private let center: any LocalNotificationScheduling
    private let nowProvider: () -> Date
    private let cooldownInterval: TimeInterval

    private var lastFiredAt: [String: Date] = [:]
    private var thresholdState: [String: ThresholdState] = [:]
    private var previousChargeStateRawByDeviceID: [UUID: UInt8] = [:]
    private var previousSocByDeviceID: [UUID: Double] = [:]

    enum ThresholdState {
        case below
        case above
    }

    init(
        settings: NotificationSettings,
        center: any LocalNotificationScheduling = UNUserNotificationCenter.current(),
        nowProvider: @escaping () -> Date = Date.init,
        cooldownInterval: TimeInterval = 3_600
    ) {
        self.settings = settings
        self.center = center
        self.nowProvider = nowProvider
        self.cooldownInterval = cooldownInterval
    }

    func requestAuthorization() async -> Bool {
        do {
            let allowed = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            settings.notificationsEnabled = allowed
            return allowed
        } catch {
            settings.notificationsEnabled = false
            return false
        }
    }

    func evaluate(reading: DeviceReading) async {
        guard settings.notificationsEnabled else {
            return
        }

        if settings.thresholdNotificationsEnabled {
            await evaluateThresholds(reading: reading)
        }

        if settings.eventNotificationsEnabled {
            await evaluateEvents(reading: reading)
        }
    }

    func checkDeviceLoss(
        registeredDevices: [RegisteredDevice],
        latestReadings: [UUID: Date]
    ) async {
        guard settings.notificationsEnabled,
              settings.deviceLossNotificationsEnabled else {
            return
        }

        let threshold = TimeInterval(settings.deviceLossThresholdHours * 3_600)
        let now = nowProvider()

        for device in registeredDevices {
            guard let lastSeen = latestReadings[device.id] ?? device.lastSeenAt else {
                continue
            }

            let elapsed = now.timeIntervalSince(lastSeen)
            guard elapsed > threshold else {
                continue
            }

            let hours = max(1, Int(elapsed / 3_600))
            await fireNotification(
                key: "\(device.id.uuidString)-loss",
                title: "Gerät offline",
                body: "\(device.name) seit \(hours)h nicht mehr empfangen."
            )
        }
    }

    private func evaluateThresholds(reading: DeviceReading) async {
        switch reading.payload {
        case let .batteryMonitor(payload):
            await evaluateLowThreshold(
                value: payload.soc,
                type: .socLow,
                reading: reading,
                valueLabel: { "\(Int($0.rounded())) %" },
                title: "Tiefentladung-Warnung"
            )
            await evaluateHighThreshold(
                value: payload.soc,
                type: .socHigh,
                reading: reading,
                valueLabel: { "\(Int($0.rounded())) %" },
                title: "Volladung erreicht"
            )
            await evaluateLowThreshold(
                value: payload.batteryVoltage,
                type: .voltageLow,
                reading: reading,
                valueLabel: { String(format: "%.1f V", $0) },
                title: "Batteriespannung niedrig"
            )
            await evaluateHighThreshold(
                value: payload.batteryVoltage,
                type: .voltageHigh,
                reading: reading,
                valueLabel: { String(format: "%.1f V", $0) },
                title: "Batteriespannung hoch"
            )
            await evaluateHighThreshold(
                value: payload.temperatureCelsius,
                type: .temperatureHigh,
                reading: reading,
                valueLabel: { String(format: "%.0f °C", $0) },
                title: "Temperatur-Warnung"
            )

        case let .solarCharger(payload):
            await evaluateHighThreshold(
                value: payload.pvPower.map(Double.init),
                type: .pvPowerPeak,
                reading: reading,
                valueLabel: { "\(Int($0.rounded())) W" },
                title: "Solar-Peak erreicht"
            )

        case let .dcDcConverter(payload):
            await evaluateLowThreshold(
                value: payload.outputVoltage,
                type: .dcDcOutputLow,
                reading: reading,
                valueLabel: { String(format: "%.1f V", $0) },
                title: "DC/DC-Ausgang niedrig"
            )
        }
    }

    private func evaluateEvents(reading: DeviceReading) async {
        switch reading.payload {
        case let .batteryMonitor(payload):
            if let soc = payload.soc {
                let previous = previousSocByDeviceID[reading.deviceID]
                if let previous, previous < 90, soc >= 99 {
                    await fireNotification(
                        key: "\(reading.deviceID.uuidString)-event-full",
                        title: "Batterie voll",
                        body: "\(reading.name) hat \(Int(soc.rounded())) % erreicht."
                    )
                }
                previousSocByDeviceID[reading.deviceID] = soc
            }

        case let .solarCharger(payload):
            await evaluateChargeStateChange(
                deviceID: reading.deviceID,
                deviceName: reading.name,
                rawValue: payload.deviceStateRaw
            )

        case let .dcDcConverter(payload):
            await evaluateChargeStateChange(
                deviceID: reading.deviceID,
                deviceName: reading.name,
                rawValue: payload.chargeStateRaw
            )
        }
    }

    private func evaluateLowThreshold(
        value: Double?,
        type: NotificationSettings.ThresholdType,
        reading: DeviceReading,
        valueLabel: (Double) -> String,
        title: String
    ) async {
        guard let value,
              let threshold = settings.threshold(for: reading.deviceID, type: type) else {
            return
        }

        let key = settings.thresholdKey(for: reading.deviceID, type: type)
        let currentState: ThresholdState = value < threshold ? .below : .above
        let previousState = thresholdState[key]
        thresholdState[key] = currentState

        guard currentState == .below,
              previousState != .below else {
            return
        }

        await fireNotification(
            key: key,
            title: title,
            body: "\(reading.name): \(valueLabel(value)) unter \(valueLabel(threshold))."
        )
    }

    private func evaluateHighThreshold(
        value: Double?,
        type: NotificationSettings.ThresholdType,
        reading: DeviceReading,
        valueLabel: (Double) -> String,
        title: String
    ) async {
        guard let value,
              let threshold = settings.threshold(for: reading.deviceID, type: type) else {
            return
        }

        let key = settings.thresholdKey(for: reading.deviceID, type: type)
        let currentState: ThresholdState = value >= threshold ? .above : .below
        let previousState = thresholdState[key]
        thresholdState[key] = currentState

        guard currentState == .above,
              previousState != .above else {
            return
        }

        await fireNotification(
            key: key,
            title: title,
            body: "\(reading.name): \(valueLabel(value)) erreicht \(valueLabel(threshold))."
        )
    }

    private func evaluateChargeStateChange(
        deviceID: UUID,
        deviceName: String,
        rawValue: UInt8?
    ) async {
        guard let rawValue else {
            return
        }

        defer {
            previousChargeStateRawByDeviceID[deviceID] = rawValue
        }

        guard let previous = previousChargeStateRawByDeviceID[deviceID],
              previous != rawValue else {
            return
        }

        await fireNotification(
            key: "\(deviceID.uuidString)-event-state",
            title: "Ladezustand geändert",
            body: "\(deviceName): \(stateName(rawValue))"
        )
    }

    private func fireNotification(
        key: String,
        title: String,
        body: String
    ) async {
        let now = nowProvider()
        if let last = lastFiredAt[key],
           now.timeIntervalSince(last) < cooldownInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(key)-\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
        lastFiredAt[key] = now
    }

    private func stateName(_ rawValue: UInt8) -> String {
        switch rawValue {
        case 0:
            return "Aus"
        case 1:
            return "Standby"
        case 2:
            return "Fehler"
        case 3:
            return "Bulk"
        case 4:
            return "Absorption"
        case 5:
            return "Float"
        case 6:
            return "Lagerung"
        default:
            return "Status \(rawValue)"
        }
    }
}
