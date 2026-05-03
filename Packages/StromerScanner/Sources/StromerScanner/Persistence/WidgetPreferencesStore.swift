import Foundation

public enum StromerMediumWidgetMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case battery
    case solar
    case dcDc
    case manual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic:
            return "Automatisch"
        case .battery:
            return "Batterie"
        case .solar:
            return "Solar"
        case .dcDc:
            return "DC/DC"
        case .manual:
            return "Manuell"
        }
    }

    public var description: String {
        switch self {
        case .automatic:
            return "Stromer wählt die wichtigsten Geräte."
        case .battery:
            return "Batterie-Geräte stehen im Vordergrund."
        case .solar:
            return "MPPT- und Solar-Werte stehen im Vordergrund."
        case .dcDc:
            return "Orion/DC-DC-Werte stehen im Vordergrund."
        case .manual:
            return "Du wählst bis zu drei Geräte selbst."
        }
    }
}

public struct StromerWidgetPreferences: Codable, Equatable, Sendable {
    public static let maxMediumDevices = 3

    public var mediumMode: StromerMediumWidgetMode
    public var mediumDeviceIDs: [UUID]

    public init(
        mediumMode: StromerMediumWidgetMode = .automatic,
        mediumDeviceIDs: [UUID] = []
    ) {
        self.mediumMode = mediumMode
        self.mediumDeviceIDs = Array(mediumDeviceIDs.prefix(Self.maxMediumDevices))
    }

    public static let `default` = StromerWidgetPreferences()
}

public protocol WidgetPreferenceStoring: Sendable {
    func savePreferences(_ preferences: StromerWidgetPreferences) throws
    func loadPreferences() -> StromerWidgetPreferences
}

public final class AppGroupWidgetPreferenceStore: WidgetPreferenceStoring, @unchecked Sendable {
    private let backing: AppGroupKeyValueStoring
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init(
        suiteName: String = StromerIdentifiers.appGroup,
        key: String = StromerIdentifiers.widgetPreferencesStoreKey
    ) throws {
        try self.init(
            backing: UserDefaultsKeyValueStore(suiteName: suiteName),
            key: key
        )
    }

    public init(
        backing: AppGroupKeyValueStoring,
        key: String = StromerIdentifiers.widgetPreferencesStoreKey
    ) {
        self.backing = backing
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func savePreferences(_ preferences: StromerWidgetPreferences) throws {
        let data = try encoder.encode(preferences)
        backing.set(data, forKey: key)
    }

    public func loadPreferences() -> StromerWidgetPreferences {
        guard let data = backing.data(forKey: key),
              let preferences = try? decoder.decode(StromerWidgetPreferences.self, from: data)
        else {
            return .default
        }

        return StromerWidgetPreferences(
            mediumMode: preferences.mediumMode,
            mediumDeviceIDs: preferences.mediumDeviceIDs
        )
    }
}
