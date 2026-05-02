import Foundation
import VictronParser

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
        case let .dcDcConverter(payload):
            let stateTitle = chargerStateTitle(payload.chargeStateRaw)
            let offReason = dcDcOffReasonTitle(payload.offReasonRaw)
            let input = payload.inputVoltage.map { "Eingang \(number($0, digits: 2)) V" }

            let secondaryParts: [String?] = [
                input,
                payload.chargeStateRaw == nil ? nil : stateTitle,
                payload.offReasonRaw == DcDcOffReason.noReason.rawValue ? nil : offReason
            ]
            let secondary = secondaryParts.compactMap { $0 }.joined(separator: " • ")

            if let outputVoltage = payload.outputVoltage {
                return DeviceReadingSummary(
                    label: "Ausgangsspannung",
                    value: outputVoltage,
                    displayValue: number(outputVoltage, digits: 2),
                    unit: "V",
                    secondary: secondary.isEmpty ? "DC/DC Converter" : secondary,
                    deviceTypeIcon: "arrow.left.arrow.right.circle.fill",
                    deviceTypeTitle: "Orion Smart"
                )
            }

            if let inputVoltage = payload.inputVoltage {
                return DeviceReadingSummary(
                    label: "Eingangsspannung",
                    value: inputVoltage,
                    displayValue: number(inputVoltage, digits: 2),
                    unit: "V",
                    secondary: secondary.isEmpty ? stateTitle : secondary,
                    deviceTypeIcon: "arrow.left.arrow.right.circle.fill",
                    deviceTypeTitle: "Orion Smart"
                )
            }

            if payload.chargeStateRaw != nil {
                return DeviceReadingSummary(
                    label: "Status",
                    value: nil,
                    displayValue: stateTitle,
                    unit: "",
                    secondary: offReason,
                    deviceTypeIcon: "arrow.left.arrow.right.circle.fill",
                    deviceTypeTitle: "Orion Smart"
                )
            }

            return DeviceReadingSummary(
                label: "Ausgangsspannung",
                value: nil,
                displayValue: "--",
                unit: "V",
                secondary: "Keine Messwerte",
                deviceTypeIcon: "arrow.left.arrow.right.circle.fill",
                deviceTypeTitle: "Orion Smart"
            )
        }
    }

    public static func icon(forRecordType recordType: UInt8?) -> String {
        switch recordType {
        case 0x02:
            return "battery.100.bolt"
        case 0x01:
            return "sun.max.fill"
        case 0x04:
            return "arrow.left.arrow.right.circle.fill"
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
        case 0x04:
            return "Orion Smart"
        default:
            return "Victron"
        }
    }

    public static func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    public static func chargerStateTitle(_ rawValue: UInt8?) -> String {
        guard let rawValue else {
            return "Nicht verfügbar"
        }

        let state = ChargerState(rawValue: rawValue)
        switch state.knownName {
        case "off":
            return "Aus"
        case "lowPower":
            return "Niedrige Leistung"
        case "fault":
            return "Fehler"
        case "bulk":
            return "Bulk"
        case "absorption":
            return "Absorption"
        case "float":
            return "Float"
        case "storage":
            return "Lagerung"
        case "equalizeManual":
            return "Ausgleich"
        case "inverting":
            return "Inverter"
        case "powerSupply":
            return "Netzteil"
        case "startingUp":
            return "Startet"
        case "repeatedAbsorption":
            return "Wiederholte Absorption"
        case "recondition":
            return "Rekonditionierung"
        case "batterySafe":
            return "Battery Safe"
        case "active":
            return "Aktiv"
        case "externalControl":
            return "Externe Steuerung"
        default:
            return "Unbekannt (\(rawValue))"
        }
    }

    public static func dcDcOffReasonTitle(_ rawValue: UInt32) -> String {
        DcDcOffReason(rawValue: rawValue).knownName ?? hex(rawValue)
    }

    public static func hex(_ value: UInt32) -> String {
        "0x" + String(format: "%08X", value)
    }
}
