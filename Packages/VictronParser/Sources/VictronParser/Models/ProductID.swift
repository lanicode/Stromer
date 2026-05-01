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
        0xC038: "SmartShunt 300A/50mV"
    ]
}
