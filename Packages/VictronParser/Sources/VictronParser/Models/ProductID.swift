import Foundation

public struct ProductID: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public var modelName: String {
        Self.modelNames[rawValue] ?? "<Unknown device: \(rawValue)>"
    }

    private static let modelNames: [UInt16: String] = [
        0xA042: "BlueSolar Charger MPPT 75/15",
        0xA057: "SmartSolar Charger MPPT 100/50",
        0xA380: "BMV-710 Smart",
        0xA381: "BMV-712 Smart",
        0xA382: "BMV-710H Smart",
        0xA383: "BMV-712 Smart",
        0xA389: "SmartShunt 500A/50mV",
        0xA38A: "SmartShunt 1000A/50mV",
        0xA38B: "SmartShunt 2000A/50mV",
        0xA38C: "SmartShunt IP67 500A/50mV",
        0xA38D: "SmartShunt IP67 1000A/50mV",
        0xA38E: "SmartShunt IP67 2000A/50mV",
        0xC030: "SmartShunt IP65 500A/50mV",
        0xC031: "SmartShunt IP65 1000A/50mV",
        0xC032: "SmartShunt IP65 2000A/50mV",
        0xC034: "BMV-800 Smart",
        0xC035: "SmartShunt IP65 500A/50mV",
        0xC036: "SmartShunt IP65 1000A/50mV",
        0xC037: "SmartShunt IP65 2000A/50mV",
        0xC038: "SmartShunt 300A/50mV",
        0xA3C0: "Orion Smart 12V/12V-18A DC-DC Converter",
        0xA3C1: "Orion Smart 12V/24V-10A DC-DC Converter",
        0xA3C2: "Orion Smart 24V/12V-20A DC-DC Converter",
        0xA3C3: "Orion Smart 24V/24V-12A DC-DC Converter",
        0xA3C4: "Orion Smart 24V/48V-6A DC-DC Converter",
        0xA3C5: "Orion Smart 48V/12V-20A DC-DC Converter",
        0xA3C6: "Orion Smart 48V/24V-12A DC-DC Converter",
        0xA3C7: "Orion Smart 48V/48V-6A DC-DC Converter",
        0xA3C8: "Orion Smart 12V/12V-30A DC-DC Converter",
        0xA3C9: "Orion Smart 12V/24V-15A DC-DC Converter",
        0xA3CA: "Orion Smart 24V/12V-30A DC-DC Converter",
        0xA3CB: "Orion Smart 24V/24V-17A DC-DC Converter",
        0xA3CC: "Orion Smart 24V/48V-8.5A DC-DC Converter",
        0xA3CD: "Orion Smart 48V/12V-30A DC-DC Converter",
        0xA3CE: "Orion Smart 48V/24V-16A DC-DC Converter",
        0xA3CF: "Orion Smart 48V/48V-8A DC-DC Converter",
        0xA3D0: "Orion Smart 12V/12V-30A Buck-Boost Converter",
        0xA3D1: "Orion Smart 12V/24V-15A Buck-Boost Converter",
        0xA3D2: "Orion Smart Orion 24V/12V-30A Buck-Boost Converter",
        0xA3D3: "Orion Smart Orion 24V/24V-17A Buck-Boost Converter"
    ]
}
