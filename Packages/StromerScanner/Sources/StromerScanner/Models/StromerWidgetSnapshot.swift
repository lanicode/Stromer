import Foundation

public enum StromerWidgetSnapshotStatus: String, Codable, Equatable, Sendable {
    case ready
    case noDevices
    case deviceMissing
}

public struct StromerWidgetDeviceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let deviceTypeIcon: String
    public let deviceTypeTitle: String
    public let mainLabel: String
    public let mainValue: String
    public let mainUnit: String
    public let secondary: String
    public let lastUpdated: Date?
    public let relativeLastUpdated: String
    public let freshness: DeviceFreshness

    public init(
        id: UUID,
        name: String,
        deviceTypeIcon: String,
        deviceTypeTitle: String,
        mainLabel: String,
        mainValue: String,
        mainUnit: String,
        secondary: String,
        lastUpdated: Date?,
        relativeLastUpdated: String,
        freshness: DeviceFreshness
    ) {
        self.id = id
        self.name = name
        self.deviceTypeIcon = deviceTypeIcon
        self.deviceTypeTitle = deviceTypeTitle
        self.mainLabel = mainLabel
        self.mainValue = mainValue
        self.mainUnit = mainUnit
        self.secondary = secondary
        self.lastUpdated = lastUpdated
        self.relativeLastUpdated = relativeLastUpdated
        self.freshness = freshness
    }

    public var isDimmed: Bool {
        freshness == .stale || freshness == .missing
    }
}

public struct StromerWidgetSnapshot: Codable, Equatable, Sendable {
    public let date: Date
    public let devices: [StromerWidgetDeviceSnapshot]
    public let status: StromerWidgetSnapshotStatus
    public let message: String

    public init(
        date: Date,
        devices: [StromerWidgetDeviceSnapshot],
        status: StromerWidgetSnapshotStatus,
        message: String
    ) {
        self.date = date
        self.devices = devices
        self.status = status
        self.message = message
    }

    public static func placeholder(date: Date = .now) -> StromerWidgetSnapshot {
        StromerWidgetSnapshot(
            date: date,
            devices: [
                StromerWidgetDeviceSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    name: "Stromer",
                    deviceTypeIcon: "bolt.fill",
                    deviceTypeTitle: "Victron",
                    mainLabel: "Live",
                    mainValue: "--",
                    mainUnit: "",
                    secondary: "Gerät hinzufügen",
                    lastUpdated: nil,
                    relativeLastUpdated: "noch nie",
                    freshness: .missing
                )
            ],
            status: .noDevices,
            message: "Gerät in Stromer hinzufügen"
        )
    }
}

public struct StromerWidgetTimelineSnapshot: Equatable, Sendable {
    public let entries: [StromerWidgetSnapshot]
    public let reloadAfter: Date

    public init(entries: [StromerWidgetSnapshot], reloadAfter: Date) {
        self.entries = entries
        self.reloadAfter = reloadAfter
    }
}

public struct StromerWidgetDeviceOption: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
