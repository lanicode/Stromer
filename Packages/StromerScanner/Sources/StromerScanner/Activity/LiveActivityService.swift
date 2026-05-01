import Foundation

public protocol LiveActivityControlling: Sendable {
    associatedtype ActivityHandle: Sendable

    func start(
        descriptor: StromerActivityDescriptor,
        contentState: StromerActivityContentState
    ) async throws -> ActivityHandle

    func update(
        _ activity: ActivityHandle,
        contentState: StromerActivityContentState
    ) async

    func end(_ activity: ActivityHandle) async
    func id(for activity: ActivityHandle) -> String
}

#if os(iOS)
import ActivityKit

public struct ActivityKitActivityHandle: @unchecked Sendable {
    public let activity: Activity<StromerActivityAttributes>

    public init(activity: Activity<StromerActivityAttributes>) {
        self.activity = activity
    }
}

public struct ActivityKitActivityClient: LiveActivityControlling {
    public init() {}

    public func start(
        descriptor: StromerActivityDescriptor,
        contentState: StromerActivityContentState
    ) async throws -> ActivityKitActivityHandle {
        let activity = try Activity.request(
            attributes: StromerActivityAttributes(descriptor: descriptor),
            content: ActivityContent(state: contentState, staleDate: nil),
            pushType: nil
        )
        return ActivityKitActivityHandle(activity: activity)
    }

    public func update(
        _ activity: ActivityKitActivityHandle,
        contentState: StromerActivityContentState
    ) async {
        await activity.activity.update(ActivityContent(state: contentState, staleDate: nil))
    }

    public func end(_ activity: ActivityKitActivityHandle) async {
        await activity.activity.end(nil, dismissalPolicy: .immediate)
    }

    public func id(for activity: ActivityKitActivityHandle) -> String {
        activity.activity.id
    }
}
#endif

@MainActor
public final class LiveActivityService<Client: LiveActivityControlling> {
    public private(set) var activeActivitiesByDeviceID: [UUID: Client.ActivityHandle]

    private let client: Client

    public init(
        client: Client,
        activeActivitiesByDeviceID: [UUID: Client.ActivityHandle] = [:]
    ) {
        self.client = client
        self.activeActivitiesByDeviceID = activeActivitiesByDeviceID
    }

    @discardableResult
    public func start(
        for device: RegisteredDevice,
        reading: DeviceReading
    ) async throws -> Client.ActivityHandle {
        if let activity = activeActivitiesByDeviceID[device.id] {
            await update(activity, reading: reading)
            return activity
        }

        let summary = DeviceReadingPresentation.summary(
            reading: reading,
            fallbackRecordType: reading.recordType
        )
        let descriptor = StromerActivityDescriptor(
            deviceID: device.id,
            deviceName: device.name,
            deviceTypeIcon: summary.deviceTypeIcon
        )
        let contentState = Self.contentState(for: reading)
        let activity = try await client.start(
            descriptor: descriptor,
            contentState: contentState
        )
        activeActivitiesByDeviceID[device.id] = activity
        return activity
    }

    public func update(activityID: String, reading: DeviceReading) async {
        guard let pair = activeActivitiesByDeviceID.first(where: { client.id(for: $0.value) == activityID }) else {
            return
        }

        await update(pair.value, reading: reading)
    }

    public func update(for deviceID: UUID, reading: DeviceReading) async {
        guard let activity = activeActivitiesByDeviceID[deviceID] else {
            return
        }

        await update(activity, reading: reading)
    }

    public func end(activityID: String) async {
        guard let pair = activeActivitiesByDeviceID.first(where: { client.id(for: $0.value) == activityID }) else {
            return
        }

        await client.end(pair.value)
        activeActivitiesByDeviceID.removeValue(forKey: pair.key)
    }

    public func end(for deviceID: UUID) async {
        guard let activity = activeActivitiesByDeviceID[deviceID] else {
            return
        }

        await client.end(activity)
        activeActivitiesByDeviceID.removeValue(forKey: deviceID)
    }

    public func activityID(for deviceID: UUID) -> String? {
        activeActivitiesByDeviceID[deviceID].map { client.id(for: $0) }
    }

    public func hasActiveActivity(for deviceID: UUID) -> Bool {
        activeActivitiesByDeviceID[deviceID] != nil
    }

    public var activeDeviceIDs: Set<UUID> {
        Set(activeActivitiesByDeviceID.keys)
    }

    private func update(
        _ activity: Client.ActivityHandle,
        reading: DeviceReading
    ) async {
        await client.update(activity, contentState: Self.contentState(for: reading))
    }

    public static func contentState(
        for reading: DeviceReading
    ) -> StromerActivityContentState {
        let summary = DeviceReadingPresentation.summary(
            reading: reading,
            fallbackRecordType: reading.recordType
        )

        return StromerActivityContentState(
            value: summary.value ?? 0,
            unit: summary.unit,
            secondary: summary.secondary,
            lastUpdated: reading.timestamp,
            freshness: reading.freshness.rawValue
        )
    }
}
