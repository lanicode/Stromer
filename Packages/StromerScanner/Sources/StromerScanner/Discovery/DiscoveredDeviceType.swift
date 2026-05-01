import Foundation

public enum DiscoveredDeviceType: String, Codable, Equatable, Sendable {
    case solarCharger
    case batteryMonitor
    case inverter
    case dcDcConverter
    case smartLithium
    case acCharger
    case smartBatteryProtect
    case lynxBMS
    case veBus
    case multiRS
    case inverterRS
    case dcEnergyMeter
    case orionXS
    case unknown

    public var title: String {
        switch self {
        case .solarCharger:
            return "MPPT"
        case .batteryMonitor:
            return "SmartShunt / BMV"
        case .inverter:
            return "Phoenix Inverter"
        case .dcDcConverter:
            return "Orion Smart"
        case .smartLithium:
            return "SmartLithium"
        case .acCharger:
            return "AC Charger"
        case .smartBatteryProtect:
            return "Smart BatteryProtect"
        case .lynxBMS:
            return "Lynx BMS"
        case .veBus:
            return "VE.Bus"
        case .multiRS:
            return "Multi RS"
        case .inverterRS:
            return "Inverter RS"
        case .dcEnergyMeter:
            return "DC Energy Meter"
        case .orionXS:
            return "Orion XS"
        case .unknown:
            return "Unbekannt"
        }
    }

    public var systemImageName: String {
        switch self {
        case .solarCharger:
            return "sun.max"
        case .batteryMonitor:
            return "battery.100"
        case .inverter:
            return "powerplug"
        case .dcDcConverter, .orionXS:
            return "arrow.left.arrow.right"
        case .smartLithium:
            return "batteryblock"
        case .acCharger:
            return "bolt.badge.batteryblock"
        case .smartBatteryProtect:
            return "shield"
        case .lynxBMS:
            return "rectangle.connected.to.line.below"
        case .veBus, .multiRS, .inverterRS, .dcEnergyMeter:
            return "bolt.horizontal"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
