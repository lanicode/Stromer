import Foundation
import VictronParser

public struct DeviceRegistryMatch: Equatable, Sendable {
    public let device: RegisteredDevice
    public let record: VictronRecord
    public let advertisement: RawAdvertisement
}

public enum DeviceRegistryMatchResult: Equatable, Sendable {
    case matched(DeviceRegistryMatch)
    case noMatch
    case ambiguous
}

@MainActor
public final class DeviceRegistry {
    public private(set) var devices: [RegisteredDevice]

    public init(devices: [RegisteredDevice] = []) {
        self.devices = devices
    }

    @discardableResult
    public func register(
        id: UUID = UUID(),
        name: String,
        advertisementKey: Data
    ) throws -> RegisteredDevice {
        guard advertisementKey.count == 16 else {
            throw ScannerError.invalidAdvertisementKeyLength(advertisementKey.count)
        }

        let device = RegisteredDevice(
            id: id,
            name: name,
            advertisementKey: advertisementKey
        )
        devices.append(device)
        return device
    }

    public func replaceDevices(_ devices: [RegisteredDevice]) {
        self.devices = devices
    }

    public func upsert(_ device: RegisteredDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    public func device(id: UUID) -> RegisteredDevice? {
        devices.first { $0.id == id }
    }

    public func match(_ advertisement: RawAdvertisement) -> DeviceRegistryMatchResult {
        var candidates: [(index: Int, device: RegisteredDevice, record: VictronRecord)] = []

        for index in devices.indices {
            let device = devices[index]
            guard device.advertisementKey.count == 16 else {
                continue
            }

            guard case let .success(record) = parseVictronAdvertisement(
                manufacturerData: advertisement.manufacturerData,
                key: device.advertisementKey
            ) else {
                continue
            }

            guard matchesKnownConstraints(device: device, record: record) else {
                continue
            }

            candidates.append((index, device, record))
        }

        if candidates.isEmpty {
            return .noMatch
        }

        let peripheralMatches = candidates.filter {
            $0.device.peripheralID == advertisement.peripheralID
        }

        if peripheralMatches.count == 1, let match = peripheralMatches.first {
            return apply(match, advertisement: advertisement)
        }

        guard candidates.count == 1, let match = candidates.first else {
            return .ambiguous
        }

        return apply(match, advertisement: advertisement)
    }

    private func apply(
        _ match: (index: Int, device: RegisteredDevice, record: VictronRecord),
        advertisement: RawAdvertisement
    ) -> DeviceRegistryMatchResult {
        var updated = match.device
        updated.peripheralID = advertisement.peripheralID
        if let localName = advertisement.localName {
            updated.localName = localName
        }
        updated.productID = match.record.productID.rawValue
        updated.recordType = recordType(for: match.record)
        updated.lastSeenAt = advertisement.timestamp
        updated.lastRSSI = advertisement.rssi
        devices[match.index] = updated

        return .matched(DeviceRegistryMatch(
            device: updated,
            record: match.record,
            advertisement: advertisement
        ))
    }

    private func matchesKnownConstraints(
        device: RegisteredDevice,
        record: VictronRecord
    ) -> Bool {
        if let productID = device.productID, productID != record.productID.rawValue {
            return false
        }

        if let recordType = device.recordType, recordType != self.recordType(for: record) {
            return false
        }

        return true
    }

    private func recordType(for record: VictronRecord) -> UInt8 {
        switch record {
        case .solarCharger:
            return 0x01
        case .batteryMonitor:
            return 0x02
        case .dcDcConverter:
            return 0x04
        }
    }
}
