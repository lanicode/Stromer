import Foundation

@MainActor
public final class DiscoveryStore {
    public static let fullVisibilityDuration: TimeInterval = 30
    public static let removalDuration: TimeInterval = 90

    private var devicesByPeripheralID: [UUID: StoredDiscovery] = [:]
    private let now: @Sendable () -> Date
    private let registeredDevices: @MainActor @Sendable () -> [RegisteredDevice]

    public init(
        now: @escaping @Sendable () -> Date = Date.init,
        registeredDevices: @escaping @MainActor @Sendable () -> [RegisteredDevice] = { [] }
    ) {
        self.now = now
        self.registeredDevices = registeredDevices
    }

    @discardableResult
    public func update(rawAdvertisement: RawAdvertisement, rssi: Int) -> DiscoveredDevice? {
        let adjustedAdvertisement = RawAdvertisement(
            peripheralID: rawAdvertisement.peripheralID,
            localName: rawAdvertisement.localName,
            manufacturerData: rawAdvertisement.manufacturerData,
            rssi: rssi,
            timestamp: rawAdvertisement.timestamp
        )
        return update(rawAdvertisement: adjustedAdvertisement)
    }

    @discardableResult
    public func update(rawAdvertisement: RawAdvertisement) -> DiscoveredDevice? {
        prune()

        guard let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: rawAdvertisement.manufacturerData
        ) else {
            return nil
        }

        let supportStatus = VictronProductCatalog.supportStatus(
            productID: header.productID,
            recordType: header.recordType
        )
        let deviceType = VictronProductCatalog.deviceType(
            productID: header.productID,
            recordType: header.recordType
        )
        let modelName = VictronProductCatalog.modelName(
            productID: header.productID,
            localName: rawAdvertisement.localName
        )

        devicesByPeripheralID[rawAdvertisement.peripheralID] = StoredDiscovery(
            peripheralID: rawAdvertisement.peripheralID,
            localName: rawAdvertisement.localName,
            productID: header.productID,
            recordType: header.recordType,
            keyCheckByte: header.keyCheckByte,
            estimatedModelName: modelName,
            estimatedDeviceType: deviceType,
            supportStatus: supportStatus,
            rssi: rawAdvertisement.rssi,
            lastSeenAt: rawAdvertisement.timestamp,
            manufacturerData: rawAdvertisement.manufacturerData
        )

        return devicesByPeripheralID[rawAdvertisement.peripheralID].map(makeDevice)
    }

    public func prune() {
        let currentDate = now()
        devicesByPeripheralID = devicesByPeripheralID.filter { _, stored in
            currentDate.timeIntervalSince(stored.lastSeenAt) <= Self.removalDuration
        }
    }

    public func removeAll() {
        devicesByPeripheralID.removeAll()
    }

    public func currentDevices() -> [DiscoveredDevice] {
        // Pruning is intentionally pull/update based instead of timer based:
        // it keeps the store deterministic in tests and avoids a background task
        // for ephemeral discovery data.
        prune()

        return devicesByPeripheralID.values
            .map(makeDevice)
            .sorted { lhs, rhs in
                if lhs.isRegistered != rhs.isRegistered {
                    return !lhs.isRegistered && rhs.isRegistered
                }

                if lhs.supportStatus != rhs.supportStatus {
                    return lhs.supportStatus.sortOrder < rhs.supportStatus.sortOrder
                }

                if lhs.lastSeenAt != rhs.lastSeenAt {
                    return lhs.lastSeenAt > rhs.lastSeenAt
                }

                return lhs.estimatedModelName.localizedStandardCompare(rhs.estimatedModelName) == .orderedAscending
            }
    }

    private func makeDevice(_ stored: StoredDiscovery) -> DiscoveredDevice {
        let knownDevices = registeredDevices()
        let isRegistered = knownDevices.contains { registeredDevice in
            registeredDevice.peripheralID == stored.peripheralID
                || registeredDevice.productID == stored.productID
                    && registeredDevice.recordType == stored.recordType
                    && registeredDevice.localName == stored.localName
                    && stored.localName != nil
        }

        return DiscoveredDevice(
            peripheralID: stored.peripheralID,
            localName: stored.localName,
            productID: stored.productID,
            recordType: stored.recordType,
            keyCheckByte: stored.keyCheckByte,
            estimatedModelName: stored.estimatedModelName,
            estimatedDeviceType: stored.estimatedDeviceType,
            supportStatus: stored.supportStatus,
            rssi: stored.rssi,
            lastSeenAt: stored.lastSeenAt,
            isRegistered: isRegistered,
            displayState: displayState(lastSeenAt: stored.lastSeenAt),
            manufacturerData: stored.manufacturerData
        )
    }

    private func displayState(lastSeenAt: Date) -> DiscoveryDisplayState {
        let age = now().timeIntervalSince(lastSeenAt)
        return age < Self.fullVisibilityDuration ? .full : .dimmed
    }
}

private struct StoredDiscovery {
    let peripheralID: UUID
    let localName: String?
    let productID: UInt16
    let recordType: UInt8
    let keyCheckByte: UInt8
    let estimatedModelName: String
    let estimatedDeviceType: DiscoveredDeviceType
    let supportStatus: DiscoverySupportStatus
    let rssi: Int
    let lastSeenAt: Date
    let manufacturerData: Data
}

private extension DiscoverySupportStatus {
    var sortOrder: Int {
        switch self {
        case .supported:
            return 0
        case .plannedPhase37:
            return 1
        case .outOfScope:
            return 2
        }
    }
}
