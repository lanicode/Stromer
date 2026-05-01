import Foundation

public enum ScannerError: Error, Equatable, Sendable {
    case invalidAdvertisementKeyLength(Int)
    case noMatchingDevice
    case ambiguousDeviceMatch
    case persistenceFailed(String)
    case keychainFailed(status: Int32)
    case appGroupUnavailable(String)
}

public enum StromerIdentifiers {
    public static let appName = "stromer"
    public static let bundleIDPrefix = "com.lanicode.stromer"
    public static let appGroup = "group.com.lanicode.stromer.shared"
    public static let keychainService = "com.lanicode.stromer.victron-advertisement-key"
    public static let scannerRestoreIdentifier = "com.lanicode.stromer.scanner"
    public static let latestReadingsStoreKey = "com.lanicode.stromer.latest-readings"
    public static let registeredDevicesStoreKey = "com.lanicode.stromer.registered-devices"
}
