import Foundation
import StromerScanner
import SwiftUI
import VictronParser

struct ValueRow: View {
    let label: String
    let value: String
    let unit: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label {
                Text(label)
                    .foregroundStyle(.primary)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                }
            }
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 16)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryReadingValue {
    let label: String
    let value: String
    let unit: String?
}

enum DevicePresentation {
    static func primaryValue(
        for reading: DeviceReading?,
        device: RegisteredDevice
    ) -> PrimaryReadingValue {
        guard let reading else {
            return PrimaryReadingValue(label: "Live-Wert", value: "Warten", unit: nil)
        }

        switch reading.payload {
        case let .batteryMonitor(payload):
            if let soc = payload.soc {
                return PrimaryReadingValue(
                    label: "Ladezustand",
                    value: number(soc, digits: 0),
                    unit: "%"
                )
            }
            if let voltage = payload.batteryVoltage {
                return PrimaryReadingValue(
                    label: "Batteriespannung",
                    value: number(voltage, digits: 2),
                    unit: "V"
                )
            }
        case let .solarCharger(payload):
            if let pvPower = payload.pvPower {
                return PrimaryReadingValue(
                    label: "PV-Leistung",
                    value: "\(pvPower)",
                    unit: "W"
                )
            }
            if let yieldTodayWh = payload.yieldTodayWh {
                return PrimaryReadingValue(
                    label: "Ertrag heute",
                    value: number(yieldTodayWh, digits: 0),
                    unit: "Wh"
                )
            }
        }

        return PrimaryReadingValue(label: "Live-Wert", value: "Keine Daten", unit: nil)
    }

    static func freshness(
        for device: RegisteredDevice,
        reading: DeviceReading?
    ) -> DeviceFreshness {
        if let reading {
            return reading.freshness
        }

        return DeviceFreshness(lastSeenAt: device.lastSeenAt, now: .now)
    }

    static func systemImage(for device: RegisteredDevice, reading: DeviceReading?) -> String {
        switch reading?.payload {
        case .batteryMonitor:
            return "battery.100.bolt"
        case .solarCharger:
            return "sun.max.fill"
        case nil:
            switch device.recordType {
            case 0x02:
                return "battery.100.bolt"
            case 0x01:
                return "sun.max.fill"
            default:
                return "dot.radiowaves.left.and.right"
            }
        }
    }

    static func deviceKindTitle(for device: RegisteredDevice, reading: DeviceReading?) -> String {
        switch reading?.payload {
        case .batteryMonitor:
            return "SmartShunt / BMV"
        case .solarCharger:
            return "SmartSolar / MPPT"
        case nil:
            switch device.recordType {
            case 0x02:
                return "SmartShunt / BMV"
            case 0x01:
                return "SmartSolar / MPPT"
            default:
                return "Victron Gerät"
            }
        }
    }

    static func relativeTime(_ date: Date?) -> String {
        guard let date else {
            return "noch nie"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 {
            return "gerade eben"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "vor \(minutes) Min."
        }

        let hours = minutes / 60
        if hours < 24 {
            return "vor \(hours) Std."
        }

        let days = hours / 24
        return "vor \(days) Tagen"
    }

    static func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    static func hex(_ value: UInt16) -> String {
        "0x" + String(value, radix: 16, uppercase: true)
    }

    static func chargerStateTitle(_ rawValue: UInt8?) -> String {
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

    static func alarmLabels(rawValue: UInt16) -> [String] {
        let alarm = AlarmReason(rawValue: rawValue)
        var labels: [String] = []

        if alarm.hasLowVoltage { labels.append("Unterspannung") }
        if alarm.hasHighVoltage { labels.append("Überspannung") }
        if alarm.hasLowSOC { labels.append("SoC niedrig") }
        if alarm.hasLowStarterVoltage { labels.append("Starter niedrig") }
        if alarm.hasHighStarterVoltage { labels.append("Starter hoch") }
        if alarm.hasLowTemperature { labels.append("Temp. niedrig") }
        if alarm.hasHighTemperature { labels.append("Temp. hoch") }
        if alarm.hasMidpointDeviation { labels.append("Mittelpunkt") }
        if alarm.hasOverload { labels.append("Überlast") }
        if alarm.hasDCRipple { labels.append("DC-Ripple") }
        if alarm.hasLowACOutputVoltage { labels.append("AC niedrig") }
        if alarm.hasHighACOutputVoltage { labels.append("AC hoch") }
        if alarm.hasShortCircuit { labels.append("Kurzschluss") }
        if alarm.hasBMSLockout { labels.append("BMS Lockout") }

        return labels
    }

    static func auxModeTitle(rawValue: UInt8) -> String {
        switch AuxMode(rawValue: rawValue) {
        case .starterVoltage:
            return "Starterspannung"
        case .midpointVoltage:
            return "Mittelpunktspannung"
        case .temperature:
            return "Temperatur"
        case .disabled:
            return "Deaktiviert"
        case nil:
            return "Unbekannt"
        }
    }
}
