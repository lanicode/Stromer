import Foundation

public struct StromerActivityContentState: Codable, Hashable, Sendable {
    public let value: Double
    public let unit: String
    public let secondary: String
    public let lastUpdated: Date
    public let freshness: String

    public init(
        value: Double,
        unit: String,
        secondary: String,
        lastUpdated: Date,
        freshness: String
    ) {
        self.value = value
        self.unit = unit
        self.secondary = secondary
        self.lastUpdated = lastUpdated
        self.freshness = freshness
    }
}

public struct StromerActivityDescriptor: Codable, Hashable, Sendable {
    public let deviceID: UUID
    public let deviceName: String
    public let deviceTypeIcon: String

    public init(
        deviceID: UUID,
        deviceName: String,
        deviceTypeIcon: String
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceTypeIcon = deviceTypeIcon
    }
}

#if os(iOS)
import ActivityKit

public struct StromerActivityAttributes: ActivityAttributes {
    public typealias ContentState = StromerActivityContentState

    public let deviceID: UUID
    public let deviceName: String
    public let deviceTypeIcon: String

    public init(
        deviceID: UUID,
        deviceName: String,
        deviceTypeIcon: String
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceTypeIcon = deviceTypeIcon
    }

    public init(descriptor: StromerActivityDescriptor) {
        self.init(
            deviceID: descriptor.deviceID,
            deviceName: descriptor.deviceName,
            deviceTypeIcon: descriptor.deviceTypeIcon
        )
    }
}
#endif
