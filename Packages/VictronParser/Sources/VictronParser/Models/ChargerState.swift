public struct ChargerState: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let off = ChargerState(rawValue: 0)
    public static let lowPower = ChargerState(rawValue: 1)
    public static let fault = ChargerState(rawValue: 2)
    public static let bulk = ChargerState(rawValue: 3)
    public static let absorption = ChargerState(rawValue: 4)
    public static let float = ChargerState(rawValue: 5)
    public static let storage = ChargerState(rawValue: 6)
    public static let equalizeManual = ChargerState(rawValue: 7)
    public static let inverting = ChargerState(rawValue: 9)
    public static let powerSupply = ChargerState(rawValue: 11)
    public static let startingUp = ChargerState(rawValue: 245)
    public static let repeatedAbsorption = ChargerState(rawValue: 246)
    public static let recondition = ChargerState(rawValue: 247)
    public static let batterySafe = ChargerState(rawValue: 248)
    public static let active = ChargerState(rawValue: 249)
    public static let externalControl = ChargerState(rawValue: 252)

    public var knownName: String? {
        Self.knownNames[rawValue]
    }

    private static let knownNames: [UInt8: String] = [
        0: "off",
        1: "lowPower",
        2: "fault",
        3: "bulk",
        4: "absorption",
        5: "float",
        6: "storage",
        7: "equalizeManual",
        9: "inverting",
        11: "powerSupply",
        245: "startingUp",
        246: "repeatedAbsorption",
        247: "recondition",
        248: "batterySafe",
        249: "active",
        252: "externalControl"
    ]
}
