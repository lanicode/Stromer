import Foundation

public enum VictronProductCatalog {
    public struct CatalogEntry: Codable, Equatable, Sendable {
        public let productID: UInt16
        public let modelName: String
        public let deviceType: DiscoveredDeviceType
        public let supportStatus: DiscoverySupportStatus

        public init(
            productID: UInt16,
            modelName: String,
            deviceType: DiscoveredDeviceType,
            supportStatus: DiscoverySupportStatus
        ) {
            self.productID = productID
            self.modelName = modelName
            self.deviceType = deviceType
            self.supportStatus = supportStatus
        }
    }

    public static func lookup(productID: UInt16) -> CatalogEntry? {
        entriesByProductID[productID]
    }

    public static func supportStatus(
        productID: UInt16,
        recordType: UInt8
    ) -> DiscoverySupportStatus {
        if let status = statusForRecordType(recordType) {
            return status
        }

        return lookup(productID: productID)?.supportStatus ?? .outOfScope
    }

    public static func deviceType(
        productID: UInt16,
        recordType: UInt8
    ) -> DiscoveredDeviceType {
        if let type = deviceTypeForRecordType(recordType) {
            return type
        }

        return lookup(productID: productID)?.deviceType ?? .unknown
    }

    public static func modelName(productID: UInt16, localName: String?) -> String {
        if let entry = lookup(productID: productID) {
            return entry.modelName
        }

        if let localName, !localName.isEmpty {
            return localName
        }

        return String(format: "Victron 0x%04X", productID)
    }

    public static let entries: [CatalogEntry] = [
        .supported(0xA040, "BlueSolar MPPT 75/15", .solarCharger),
        .supported(0xA042, "BlueSolar MPPT 100/15", .solarCharger),
        .supported(0xA043, "BlueSolar MPPT 75/50", .solarCharger),
        .supported(0xA045, "BlueSolar MPPT 100/50", .solarCharger),
        .supported(0xA046, "BlueSolar MPPT 150/35", .solarCharger),
        .supported(0xA047, "BlueSolar MPPT 75/10", .solarCharger),
        .supported(0xA048, "BlueSolar MPPT 150/45", .solarCharger),
        .supported(0xA04F, "SmartSolar MPPT 75/15", .solarCharger),
        .supported(0xA055, "SmartSolar MPPT 100/15", .solarCharger),
        .supported(0xA056, "SmartSolar MPPT 100/30", .solarCharger),
        .supported(0xA057, "SmartSolar MPPT 100/50", .solarCharger),
        .supported(0xA058, "SmartSolar MPPT 150/35", .solarCharger),
        .supported(0xA059, "SmartSolar MPPT 75/10", .solarCharger),
        .supported(0xA05A, "SmartSolar MPPT 150/45", .solarCharger),
        .supported(0xA05B, "SmartSolar MPPT 150/60", .solarCharger),
        .supported(0xA05C, "SmartSolar MPPT 150/70", .solarCharger),
        .supported(0xA05D, "SmartSolar MPPT 250/100", .solarCharger),
        .supported(0xA061, "SmartSolar MPPT 100/20", .solarCharger),
        .supported(0xA062, "SmartSolar MPPT 100/20 48V", .solarCharger),
        .supported(0xA063, "SmartSolar MPPT 150/85", .solarCharger),
        .supported(0xA064, "SmartSolar MPPT 150/100", .solarCharger),
        .supported(0xA065, "BlueSolar MPPT 150/70", .solarCharger),
        .supported(0xA066, "BlueSolar MPPT 150/100", .solarCharger),
        .supported(0xA067, "SmartSolar MPPT 250/85", .solarCharger),
        .supported(0xA068, "SmartSolar MPPT 250/100", .solarCharger),
        .supported(0xA069, "BlueSolar MPPT 100/30", .solarCharger),
        .supported(0xA06A, "BlueSolar MPPT 100/50", .solarCharger),
        .supported(0xA06B, "SmartSolar MPPT 250/60", .solarCharger),
        .supported(0xA06C, "SmartSolar MPPT 250/70", .solarCharger),
        .supported(0xA06D, "SmartSolar MPPT 150/45", .solarCharger),
        .supported(0xA06E, "SmartSolar MPPT 150/60", .solarCharger),
        .supported(0xA07E, "SmartSolar MPPT 75/15", .solarCharger),
        .supported(0xA102, "SmartSolar MPPT VE.Can 150/70", .solarCharger),
        .supported(0xA103, "SmartSolar MPPT VE.Can 150/85", .solarCharger),
        .supported(0xA104, "SmartSolar MPPT VE.Can 150/100", .solarCharger),
        .supported(0xA105, "BlueSolar MPPT VE.Can 150/70", .solarCharger),
        .supported(0xA106, "BlueSolar MPPT VE.Can 150/85", .solarCharger),
        .supported(0xA107, "BlueSolar MPPT VE.Can 150/100", .solarCharger),
        .supported(0xA110, "SmartSolar MPPT VE.Can 250/70", .solarCharger),
        .supported(0xA111, "SmartSolar MPPT VE.Can 250/85", .solarCharger),
        .supported(0xA112, "SmartSolar MPPT VE.Can 250/100", .solarCharger),
        .supported(0xA113, "BlueSolar MPPT VE.Can 250/70", .solarCharger),
        .supported(0xA114, "BlueSolar MPPT VE.Can 250/85", .solarCharger),
        .supported(0xA115, "BlueSolar MPPT VE.Can 250/100", .solarCharger),
        .supported(0xA380, "BMV-710 Smart", .batteryMonitor),
        .supported(0xA381, "BMV-712 Smart", .batteryMonitor),
        .supported(0xA382, "BMV-710H Smart", .batteryMonitor),
        .supported(0xA383, "BMV-712 Smart", .batteryMonitor),
        .supported(0xA389, "SmartShunt 500A/50mV", .batteryMonitor),
        .supported(0xA38A, "SmartShunt 1000A/50mV", .batteryMonitor),
        .supported(0xA38B, "SmartShunt 2000A/50mV", .batteryMonitor),
        .supported(0xA38C, "SmartShunt IP67 500A/50mV", .batteryMonitor),
        .supported(0xA38D, "SmartShunt IP67 1000A/50mV", .batteryMonitor),
        .supported(0xA38E, "SmartShunt IP67 2000A/50mV", .batteryMonitor),
        .supported(0xC030, "SmartShunt IP65 500A/50mV", .batteryMonitor),
        .supported(0xC031, "SmartShunt IP65 1000A/50mV", .batteryMonitor),
        .supported(0xC032, "SmartShunt IP65 2000A/50mV", .batteryMonitor),
        .supported(0xC033, "All-In-1 Smart", .batteryMonitor),
        .supported(0xC034, "BMV-800 Smart", .batteryMonitor),
        .supported(0xC035, "SmartShunt IP65 500A/50mV", .batteryMonitor),
        .supported(0xC036, "SmartShunt IP65 1000A/50mV", .batteryMonitor),
        .supported(0xC037, "SmartShunt IP65 2000A/50mV", .batteryMonitor),
        .planned(0xA200, "Phoenix Inverter 12/250", .inverter),
        .planned(0xA201, "Phoenix Inverter 24/250", .inverter),
        .planned(0xA211, "Phoenix Inverter 12/375", .inverter),
        .planned(0xA221, "Phoenix Inverter 12/500", .inverter),
        .planned(0xA241, "Phoenix Inverter 12/800", .inverter),
        .planned(0xA251, "Phoenix Inverter 12/1200", .inverter),
        .planned(0xA271, "Phoenix Inverter 12/1600", .inverter),
        .planned(0xA281, "Phoenix Inverter 12/2000", .inverter),
        .planned(0xA2A1, "Phoenix Inverter 12/3000", .inverter),
        .planned(0xA2B1, "Phoenix Inverter 24/3000", .inverter),
        .planned(0xA2E1, "Phoenix Inverter Smart 12/3000", .inverter),
        .planned(0xA0E0, "Smart Lithium Battery 12.8V/90Ah", .smartLithium),
        .planned(0xA0E1, "Smart Lithium Battery 12.8V/60Ah", .smartLithium),
        .planned(0xA0E2, "Smart Lithium Battery 12.8V/160Ah", .smartLithium),
        .planned(0xA0E3, "Smart Lithium Battery 12.8V/200Ah", .smartLithium),
        .planned(0xA0E4, "Smart Lithium Battery 12.8V/300Ah", .smartLithium),
        .planned(0xA0E5, "Smart Lithium Battery 12.8V/100Ah", .smartLithium),
        .planned(0xA0E6, "Smart Lithium Battery 12.8V/200Ah", .smartLithium),
        .planned(0xA0E7, "Smart Lithium Battery 12.8V/300Ah", .smartLithium),
        .planned(0xA0E8, "Smart Lithium Battery 12.8V/100Ah", .smartLithium),
        .planned(0xA0E9, "Smart Lithium Battery 12.8V/150Ah", .smartLithium),
        .planned(0xA0EA, "Smart Lithium Battery 25.6V/200Ah", .smartLithium),
        .planned(0xA0EB, "Smart Lithium Battery 12.8V/200Ah", .smartLithium),
        .planned(0xA0EC, "Smart Lithium Battery 12.8V/160Ah", .smartLithium),
        .planned(0xA0ED, "Smart Lithium Battery 12.8V/50Ah", .smartLithium),
        .planned(0xA0EE, "Smart Lithium Battery 25.6V/200Ah", .smartLithium),
        .planned(0xA0EF, "Smart Lithium Battery 25.6V/100Ah", .smartLithium),
        .planned(0xA0F0, "Smart Lithium Battery 12.8V/330Ah", .smartLithium),
        .planned(0xA0F1, "Smart Lithium Battery 25.6V/330Ah", .smartLithium),
        .planned(0xA0F2, "Smart Lithium Battery 12.8V/300Ah", .smartLithium),
        .planned(0xA340, "Phoenix Smart IP43 Charger 12|50 (1+1) 230V", .acCharger),
        .planned(0xA341, "Phoenix Smart IP43 Charger 12|50 (3) 230V", .acCharger),
        .planned(0xA342, "Phoenix Smart IP43 Charger 24|25 (1+1) 230V", .acCharger),
        .planned(0xA343, "Phoenix Smart IP43 Charger 24|25 (3) 230V", .acCharger),
        .planned(0xA344, "Phoenix Smart IP43 Charger 12|30 (1+1) 230V", .acCharger),
        .planned(0xA345, "Phoenix Smart IP43 Charger 12|30 (3) 230V", .acCharger),
        .planned(0xA346, "Phoenix Smart IP43 Charger 24|16 (1+1) 230V", .acCharger),
        .planned(0xA347, "Phoenix Smart IP43 Charger 24|16 (3) 230V", .acCharger),
        .planned(0xA350, "Phoenix Smart IP43 Charger 12|50 (1+1) 120-240V", .acCharger),
        .planned(0xA351, "Phoenix Smart IP43 Charger 12|50 (3) 120-240V", .acCharger),
        .planned(0xA352, "Phoenix Smart IP43 Charger 24|25 (1+1) 120-240V", .acCharger),
        .planned(0xA353, "Phoenix Smart IP43 Charger 24|25 (3) 120-240V", .acCharger),
        .planned(0xA354, "Phoenix Smart IP43 Charger 12|30 (1+1) 120-240V", .acCharger),
        .planned(0xA355, "Phoenix Smart IP43 Charger 12|30 (3) 120-240V", .acCharger),
        .planned(0xA356, "Phoenix Smart IP43 Charger 24|16 (1+1) 120-240V", .acCharger),
        .planned(0xA357, "Phoenix Smart IP43 Charger 24|16 (3) 120-240V", .acCharger),
        .planned(0xA3B0, "Smart BatteryProtect 12/24V-65A", .smartBatteryProtect),
        .planned(0xA3B1, "Smart BatteryProtect 12/24V-100A", .smartBatteryProtect),
        .planned(0xA3B2, "Smart BatteryProtect 12/24V-220A", .smartBatteryProtect),
        .planned(0xA3B3, "Smart BatteryProtect 48V-100A", .smartBatteryProtect),
        .supported(0xA3C0, "Orion Smart 12V/12V-18A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C1, "Orion Smart 12V/24V-10A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C2, "Orion Smart 24V/12V-20A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C3, "Orion Smart 24V/24V-12A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C4, "Orion Smart 24V/48V-6A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C5, "Orion Smart 48V/12V-20A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C6, "Orion Smart 48V/24V-12A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C7, "Orion Smart 48V/48V-6A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C8, "Orion Smart 12V/12V-30A DC-DC Converter", .dcDcConverter),
        .supported(0xA3C9, "Orion Smart 12V/24V-15A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CA, "Orion Smart 24V/12V-30A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CB, "Orion Smart 24V/24V-17A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CC, "Orion Smart 24V/48V-8.5A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CD, "Orion Smart 48V/12V-30A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CE, "Orion Smart 48V/24V-16A DC-DC Converter", .dcDcConverter),
        .supported(0xA3CF, "Orion Smart 48V/48V-8A DC-DC Converter", .dcDcConverter),
        .supported(0xA3D0, "Orion Smart 12V/12V-30A Buck-Boost Converter", .dcDcConverter),
        .supported(0xA3D1, "Orion Smart 12V/24V-15A Buck-Boost Converter", .dcDcConverter),
        .supported(0xA3D2, "Orion Smart Orion 24V/12V-30A Buck-Boost Converter", .dcDcConverter),
        .supported(0xA3D3, "Orion Smart Orion 24V/24V-17A Buck-Boost Converter", .dcDcConverter),
        .outOfScope(0xA3E5, "Lynx Smart BMS 500", .lynxBMS),
        .outOfScope(0xA3E6, "Lynx Smart BMS 1000", .lynxBMS),
        .outOfScope(0xA401, "Inverter RS Smart Solar 48/6000", .inverterRS),
        .outOfScope(0xA402, "Inverter RS Smart 48/6000", .inverterRS),
        .outOfScope(0xA441, "Multi RS Solar 48/6000", .multiRS),
        .outOfScope(0xA442, "Multi RS Solar 48/6000 Dual Tracker", .multiRS),
        .outOfScope(0xA443, "Multi RS 48/6000", .multiRS),
        .outOfScope(0xA444, "Multi RS Solar 48/6000", .multiRS)
    ]

    private static let entriesByProductID = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.productID, $0) }
    )

    private static func statusForRecordType(_ recordType: UInt8) -> DiscoverySupportStatus? {
        switch recordType {
        case 0x01, 0x02, 0x04:
            return .supported
        case 0x03, 0x05, 0x08, 0x09:
            return .plannedPhase37
        case 0x06, 0x0A, 0x0B, 0x0C, 0x0D, 0x0F:
            return .outOfScope
        default:
            return nil
        }
    }

    private static func deviceTypeForRecordType(_ recordType: UInt8) -> DiscoveredDeviceType? {
        switch recordType {
        case 0x01:
            return .solarCharger
        case 0x02:
            return .batteryMonitor
        case 0x03:
            return .inverter
        case 0x04:
            return .dcDcConverter
        case 0x05:
            return .smartLithium
        case 0x06:
            return .veBus
        case 0x08:
            return .acCharger
        case 0x09:
            return .smartBatteryProtect
        case 0x0A:
            return .lynxBMS
        case 0x0B:
            return .veBus
        case 0x0C:
            return .multiRS
        case 0x0D:
            return .inverterRS
        case 0x0F:
            return .dcEnergyMeter
        default:
            return nil
        }
    }
}

private extension VictronProductCatalog.CatalogEntry {
    static func supported(
        _ productID: UInt16,
        _ modelName: String,
        _ deviceType: DiscoveredDeviceType
    ) -> Self {
        Self(
            productID: productID,
            modelName: modelName,
            deviceType: deviceType,
            supportStatus: .supported
        )
    }

    static func planned(
        _ productID: UInt16,
        _ modelName: String,
        _ deviceType: DiscoveredDeviceType
    ) -> Self {
        Self(
            productID: productID,
            modelName: modelName,
            deviceType: deviceType,
            supportStatus: .plannedPhase37
        )
    }

    static func outOfScope(
        _ productID: UInt16,
        _ modelName: String,
        _ deviceType: DiscoveredDeviceType
    ) -> Self {
        Self(
            productID: productID,
            modelName: modelName,
            deviceType: deviceType,
            supportStatus: .outOfScope
        )
    }
}
