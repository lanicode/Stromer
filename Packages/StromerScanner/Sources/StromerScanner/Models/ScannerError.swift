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
    public static let bundleIDPrefix = "com.lanicode.StromerApp"
    public static let appGroup = "group.com.lanicode.Stromer"
    public static let keychainService = "com.lanicode.StromerApp.victron-advertisement-key"
    public static let scannerRestoreIdentifier = "com.lanicode.StromerApp.scanner"
    public static let latestReadingsStoreKey = "com.lanicode.StromerApp.latest-readings"
    public static let registeredDevicesStoreKey = "com.lanicode.StromerApp.registered-devices"
    public static let widgetPreferencesStoreKey = "com.lanicode.StromerApp.widget-preferences"
}
