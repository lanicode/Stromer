import Foundation
@testable import StromerScanner
import XCTest

@MainActor
final class LiveActivityServiceTests: XCTestCase {
    func testStartUpdateEndAgainstMockActivityClient() async throws {
        let client = MockLiveActivityClient()
        let service = LiveActivityService(client: client)
        let device = RegisteredDevice(
            id: deviceID,
            name: "SmartShunt",
            advertisementKey: Data(repeating: 0xAA, count: 16),
            recordType: 0x02
        )

        let handle = try await service.start(for: device, reading: firstReading)
        XCTAssertEqual(handle.id, "activity-1")
        XCTAssertEqual(service.activityID(for: deviceID), "activity-1")
        XCTAssertEqual(client.startedStates.first?.value, 51)
        XCTAssertEqual(client.startedDescriptors.first?.deviceName, "SmartShunt")

        await service.update(activityID: "activity-1", reading: updatedReading)
        XCTAssertEqual(client.updatedStates.last?.value, 52)
        XCTAssertEqual(client.updatedStates.last?.freshness, DeviceFreshness.delayed.rawValue)

        await service.end(activityID: "activity-1")
        XCTAssertEqual(client.endedActivityIDs, ["activity-1"])
        XCTAssertFalse(service.hasActiveActivity(for: deviceID))
    }

    func testStartAgainUpdatesExistingActivityInsteadOfCreatingANewOne() async throws {
        let client = MockLiveActivityClient()
        let service = LiveActivityService(client: client)
        let device = RegisteredDevice(
            id: deviceID,
            name: "SmartShunt",
            advertisementKey: Data(repeating: 0xAA, count: 16),
            recordType: 0x02
        )

        _ = try await service.start(for: device, reading: firstReading)
        _ = try await service.start(for: device, reading: updatedReading)

        XCTAssertEqual(client.startedStates.count, 1)
        XCTAssertEqual(client.updatedStates.last?.value, 52)
    }
}

private struct MockActivityHandle: Equatable, Sendable {
    let id: String
}

private final class MockLiveActivityClient: LiveActivityControlling, @unchecked Sendable {
    private var nextActivityNumber = 1
    private(set) var startedDescriptors: [StromerActivityDescriptor] = []
    private(set) var startedStates: [StromerActivityContentState] = []
    private(set) var updatedStates: [StromerActivityContentState] = []
    private(set) var endedActivityIDs: [String] = []

    func start(
        descriptor: StromerActivityDescriptor,
        contentState: StromerActivityContentState
    ) async throws -> MockActivityHandle {
        startedDescriptors.append(descriptor)
        startedStates.append(contentState)
        let handle = MockActivityHandle(id: "activity-\(nextActivityNumber)")
        nextActivityNumber += 1
        return handle
    }

    func update(
        _ activity: MockActivityHandle,
        contentState: StromerActivityContentState
    ) async {
        updatedStates.append(contentState)
    }

    func end(_ activity: MockActivityHandle) async {
        endedActivityIDs.append(activity.id)
    }

    func id(for activity: MockActivityHandle) -> String {
        activity.id
    }
}

private let deviceID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
private let activityReferenceDate = Date(timeIntervalSince1970: 1_700_000_000)

private let firstReading = DeviceReading(
    deviceID: deviceID,
    name: "SmartShunt",
    localName: nil,
    peripheralID: nil,
    productID: 0xA389,
    recordType: 0x02,
    modelName: "SmartShunt 500A/50mV",
    rssi: -68,
    timestamp: activityReferenceDate,
    freshness: .fresh,
    payload: .batteryMonitor(BatteryMonitorReading(
        timeToGoMinutes: nil,
        batteryVoltage: 12.53,
        alarmReasonRaw: 0,
        auxModeRaw: 3,
        starterVoltage: nil,
        midpointVoltage: nil,
        temperatureCelsius: nil,
        batteryCurrent: -2.1,
        consumedAh: -20,
        soc: 51
    ))
)

private let updatedReading = DeviceReading(
    deviceID: deviceID,
    name: "SmartShunt",
    localName: nil,
    peripheralID: nil,
    productID: 0xA389,
    recordType: 0x02,
    modelName: "SmartShunt 500A/50mV",
    rssi: -67,
    timestamp: activityReferenceDate.addingTimeInterval(120),
    freshness: .delayed,
    payload: .batteryMonitor(BatteryMonitorReading(
        timeToGoMinutes: nil,
        batteryVoltage: 12.48,
        alarmReasonRaw: 0,
        auxModeRaw: 3,
        starterVoltage: nil,
        midpointVoltage: nil,
        temperatureCelsius: nil,
        batteryCurrent: -1.8,
        consumedAh: -19,
        soc: 52
    ))
)
