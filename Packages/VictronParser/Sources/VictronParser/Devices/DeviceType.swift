public enum DeviceType: UInt8, Equatable, Sendable {
    case solarCharger = 0x01
    case batteryMonitor = 0x02
    case dcDcConverter = 0x04
}
