public enum AuxMode: UInt8, Equatable, Sendable {
    case starterVoltage = 0
    case midpointVoltage = 1
    case temperature = 2
    case disabled = 3
}

public enum BatteryAuxValue: Equatable, Sendable {
    case starterVoltage(Double)
    case midpointVoltage(Double)
    case temperatureCelsius(Double)
}
