public struct AlarmReason: OptionSet, Equatable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let lowVoltage = AlarmReason(rawValue: 1 << 0)
    public static let highVoltage = AlarmReason(rawValue: 1 << 1)
    public static let lowSOC = AlarmReason(rawValue: 1 << 2)
    public static let lowStarterVoltage = AlarmReason(rawValue: 1 << 3)
    public static let highStarterVoltage = AlarmReason(rawValue: 1 << 4)
    public static let lowTemperature = AlarmReason(rawValue: 1 << 5)
    public static let highTemperature = AlarmReason(rawValue: 1 << 6)
    public static let midpointDeviation = AlarmReason(rawValue: 1 << 7)
    public static let overload = AlarmReason(rawValue: 1 << 8)
    public static let dcRipple = AlarmReason(rawValue: 1 << 9)
    public static let lowACOutputVoltage = AlarmReason(rawValue: 1 << 10)
    public static let highACOutputVoltage = AlarmReason(rawValue: 1 << 11)
    public static let shortCircuit = AlarmReason(rawValue: 1 << 12)
    public static let bmsLockout = AlarmReason(rawValue: 1 << 13)

    public var hasLowVoltage: Bool { contains(.lowVoltage) }
    public var hasHighVoltage: Bool { contains(.highVoltage) }
    public var hasLowSOC: Bool { contains(.lowSOC) }
    public var hasLowStarterVoltage: Bool { contains(.lowStarterVoltage) }
    public var hasHighStarterVoltage: Bool { contains(.highStarterVoltage) }
    public var hasLowTemperature: Bool { contains(.lowTemperature) }
    public var hasHighTemperature: Bool { contains(.highTemperature) }
    public var hasMidpointDeviation: Bool { contains(.midpointDeviation) }
    public var hasOverload: Bool { contains(.overload) }
    public var hasDCRipple: Bool { contains(.dcRipple) }
    public var hasLowACOutputVoltage: Bool { contains(.lowACOutputVoltage) }
    public var hasHighACOutputVoltage: Bool { contains(.highACOutputVoltage) }
    public var hasShortCircuit: Bool { contains(.shortCircuit) }
    public var hasBMSLockout: Bool { contains(.bmsLockout) }
}
