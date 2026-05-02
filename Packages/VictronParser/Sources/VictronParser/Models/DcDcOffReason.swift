import Foundation

public struct DcDcOffReason: RawRepresentable, Equatable, Hashable, Sendable, Codable, CustomDebugStringConvertible {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let noReason = DcDcOffReason(rawValue: 0x0000_0000)
    public static let noInputPower = DcDcOffReason(rawValue: 0x0000_0001)
    public static let switchedOffSwitch = DcDcOffReason(rawValue: 0x0000_0002)
    public static let switchedOffRegister = DcDcOffReason(rawValue: 0x0000_0004)
    public static let remoteInput = DcDcOffReason(rawValue: 0x0000_0008)
    public static let protectionActive = DcDcOffReason(rawValue: 0x0000_0010)
    public static let loadOutputDisabled = DcDcOffReason(rawValue: 0x0000_0014)
    public static let payAsYouGoOutOfCredit = DcDcOffReason(rawValue: 0x0000_0020)
    public static let bms = DcDcOffReason(rawValue: 0x0000_0040)
    public static let engineShutdown = DcDcOffReason(rawValue: 0x0000_0080)
    public static let engineShutdownAndInputVoltageLockout = DcDcOffReason(rawValue: 0x0000_0081)
    public static let analysingInputVoltage = DcDcOffReason(rawValue: 0x0000_0100)

    public var knownName: String? {
        Self.knownNames[rawValue]
    }

    public var debugDescription: String {
        knownName ?? String(format: "0x%08X", rawValue)
    }

    private static let knownNames: [UInt32: String] = [
        0x0000_0000: "Kein Grund",
        0x0000_0001: "Keine Eingangsspannung",
        0x0000_0002: "Per Schalter ausgeschaltet",
        0x0000_0004: "Per Register ausgeschaltet",
        0x0000_0008: "Remote-Eingang",
        0x0000_0010: "Schutz aktiv",
        0x0000_0014: "Load-Ausgang deaktiviert",
        0x0000_0020: "Pay-as-you-go Guthaben leer",
        0x0000_0040: "BMS",
        0x0000_0080: "Motorabschaltung",
        0x0000_0081: "Motorabschaltung und Eingangsspannungs-Sperre",
        0x0000_0100: "Eingangsspannung wird analysiert"
    ]
}
