import Foundation

public struct DeviceReadingSummary: Equatable, Sendable {
    public let label: String
    public let value: Double?
    public let displayValue: String
    public let unit: String
    public let secondary: String
    public let deviceTypeIcon: String
    public let deviceTypeTitle: String

    public init(
        label: String,
        value: Double?,
        displayValue: String,
        unit: String,
        secondary: String,
        deviceTypeIcon: String,
        deviceTypeTitle: String
    ) {
        self.label = label
        self.value = value
        self.displayValue = displayValue
        self.unit = unit
        self.secondary = secondary
        self.deviceTypeIcon = deviceTypeIcon
        self.deviceTypeTitle = deviceTypeTitle
    }
}

public enum DeviceReadingPresentation {
    public static func summary(
        reading: DeviceReading?,
        fallbackRecordType: UInt8?
    ) -> DeviceReadingSummary {
        guard let reading else {
            return DeviceReadingSummary(
                label: "Live-Wert",
                value: nil,
                displayValue: "--",
                unit: "",
                secondary: "Noch keine Live-Daten",
                deviceTypeIcon: icon(forRecordType: fallbackRecordType),
                deviceTypeTitle: title(forRecordType: fallbackRecordType)
            )
        }

        switch reading.payload {
        case let .batteryMonitor(payload):
            let voltage = payload.batteryVoltage.map { "\(number($0, digits: 2)) V" }
            let current = payload.batteryCurrent.map { "\(number($0, digits: 2)) A" }
            let secondary = [voltage, current].compactMap { $0 }.joined(separator: " • ")

            if let soc = payload.soc {
                return DeviceReadingSummary(
                    label: "SoC",
                    value: soc,
                    displayValue: number(soc, digits: 0),
                    unit: "%",
                    secondary: secondary.isEmpty ? "Batteriemonitor" : secondary,
                    deviceTypeIcon: "battery.100.bolt",
                    deviceTypeTitle: "SmartShunt"
                )
            }

            if let batteryVoltage = payload.batteryVoltage {
                return DeviceReadingSummary(
                    label: "Spannung",
                    value: batteryVoltage,
                    displayValue: number(batteryVoltage, digits: 2),
                    unit: "V",
                    secondary: current ?? "Batteriemonitor",
                    deviceTypeIcon: "battery.100.bolt",
                    deviceTypeTitle: "SmartShunt"
                )
            }

            return DeviceReadingSummary(
                label: "SoC",
                value: nil,
                displayValue: "--",
                unit: "%",
                secondary: "Keine Messwerte",
                deviceTypeIcon: "battery.100.bolt",
                deviceTypeTitle: "SmartShunt"
            )

        case let .solarCharger(payload):
            let voltage = payload.batteryVoltage.map { "\(number($0, digits: 2)) V" }
            let yield = payload.yieldTodayWh.map { "\(number($0, digits: 0)) Wh" }
            let secondary = [voltage, yield].compactMap { $0 }.joined(separator: " • ")

            if let pvPower = payload.pvPower {
                return DeviceReadingSummary(
                    label: "PV",
                    value: Double(pvPower),
                    displayValue: "\(pvPower)",
                    unit: "W",
                    secondary: secondary.isEmpty ? "Solarlader" : secondary,
                    deviceTypeIcon: "sun.max.fill",
                    deviceTypeTitle: "SmartSolar"
                )
            }

            if let yieldToday = payload.yieldTodayWh {
                return DeviceReadingSummary(
                    label: "Ertrag",
                    value: yieldToday,
                    displayValue: number(yieldToday, digits: 0),
                    unit: "Wh",
                    secondary: voltage ?? "Solarlader",
                    deviceTypeIcon: "sun.max.fill",
                    deviceTypeTitle: "SmartSolar"
                )
            }

            return DeviceReadingSummary(
                label: "PV",
                value: nil,
                displayValue: "--",
                unit: "W",
                secondary: "Keine Messwerte",
                deviceTypeIcon: "sun.max.fill",
                deviceTypeTitle: "SmartSolar"
            )
        }
    }

    public static func icon(forRecordType recordType: UInt8?) -> String {
        switch recordType {
        case 0x02:
            return "battery.100.bolt"
        case 0x01:
            return "sun.max.fill"
        default:
            return "dot.radiowaves.left.and.right"
        }
    }

    public static func title(forRecordType recordType: UInt8?) -> String {
        switch recordType {
        case 0x02:
            return "SmartShunt"
        case 0x01:
            return "SmartSolar"
        default:
            return "Victron"
        }
    }

    public static func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }
}
