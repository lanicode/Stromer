import Foundation
@testable import StromerScanner
import VictronParser
import XCTest

final class DcDcConverterReadingTests: XCTestCase {
    func testDeviceReadingInitCreatesDcDcPayload() throws {
        let reading = try dcDcReading()

        XCTAssertEqual(reading.productID, 0xA3C0)
        XCTAssertEqual(reading.recordType, 0x04)
        XCTAssertEqual(reading.modelName, "Orion Smart 12V/12V-18A DC-DC Converter")

        guard case let .dcDcConverter(payload) = reading.payload else {
            return XCTFail("Expected DC/DC converter payload")
        }

        XCTAssertEqual(payload.chargeStateRaw, 0)
        XCTAssertEqual(payload.chargerErrorCode, 0)
        XCTAssertEqual(payload.inputVoltage ?? .nan, 13.15, accuracy: 0.0001)
        XCTAssertNil(payload.outputVoltage)
        XCTAssertEqual(payload.offReasonRaw, 0x80)
    }

    func testDeviceReadingPresentationSummaryForDcDc() throws {
        let summary = DeviceReadingPresentation.summary(
            reading: try dcDcReading(),
            fallbackRecordType: 0x04
        )

        XCTAssertEqual(summary.label, "Eingangsspannung")
        XCTAssertEqual(summary.value ?? .nan, 13.15, accuracy: 0.0001)
        XCTAssertEqual(summary.displayValue, DeviceReadingPresentation.number(13.15, digits: 2))
        XCTAssertEqual(summary.unit, "V")
        XCTAssertEqual(summary.secondary, "Eingang 13,15 V • Aus • Motorabschaltung")
        XCTAssertEqual(summary.deviceTypeIcon, "arrow.left.arrow.right.circle.fill")
        XCTAssertEqual(summary.deviceTypeTitle, "Orion Smart")
    }

    func testWidgetSnapshotProviderUsesDcDcPresentation() throws {
        let device = RegisteredDeviceSnapshot(
            id: dcDcDeviceID,
            name: "Orion",
            productID: 0xA3C0,
            recordType: 0x04,
            lastSeenAt: referenceDate,
            lastRSSI: -58
        )
        let provider = StromerWidgetSnapshotProvider(
            deviceStore: SnapshotDeviceStore([device]),
            readingStore: SnapshotReadingStore([try dcDcReading()]),
            now: { referenceDate }
        )

        let snapshot = provider.snapshot(selectedDeviceID: dcDcDeviceID)
        let deviceSnapshot = snapshot.devices.first

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(deviceSnapshot?.deviceTypeTitle, "Orion Smart")
        XCTAssertEqual(deviceSnapshot?.mainLabel, "Eingangsspannung")
        XCTAssertEqual(deviceSnapshot?.mainValue, DeviceReadingPresentation.number(13.15, digits: 2))
        XCTAssertEqual(deviceSnapshot?.mainUnit, "V")
        XCTAssertEqual(deviceSnapshot?.secondary, "Eingang 13,15 V • Aus • Motorabschaltung")
    }

    func testCatalogSupportStatusForOrionRecordTypeIsSupported() {
        XCTAssertEqual(
            VictronProductCatalog.supportStatus(productID: 0xA3D0, recordType: 0x04),
            .supported
        )
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
private let dcDcDeviceID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
private let dcDcKey = data("64ba49f1a8562e45197a8e1fe50d7658")
private let dcDcAdvertisement = data("1000c0a304121d64ca8d442b90bbdf6a8cba")

private func dcDcReading() throws -> DeviceReading {
    let device = RegisteredDevice(
        id: dcDcDeviceID,
        name: "Orion",
        advertisementKey: dcDcKey,
        peripheralID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        localName: "Orion Smart"
    )
    let advertisement = RawAdvertisement(
        peripheralID: device.peripheralID!,
        localName: device.localName,
        manufacturerData: dcDcAdvertisement,
        rssi: -58,
        timestamp: referenceDate
    )

    guard case let .success(record) = parseVictronAdvertisement(
        manufacturerData: dcDcAdvertisement,
        key: dcDcKey
    ) else {
        throw ScannerError.noMatchingDevice
    }

    return DeviceReading(
        device: device,
        record: record,
        rssi: advertisement.rssi,
        timestamp: advertisement.timestamp,
        now: referenceDate
    )
}

private final class SnapshotDeviceStore: RegisteredDeviceSnapshotStoring, @unchecked Sendable {
    private var devices: [RegisteredDeviceSnapshot]

    init(_ devices: [RegisteredDeviceSnapshot]) {
        self.devices = devices
    }

    func saveDeviceSnapshots(_ snapshots: [RegisteredDeviceSnapshot]) throws {
        devices = snapshots
    }

    func loadDeviceSnapshots() throws -> [RegisteredDeviceSnapshot] {
        devices
    }

    func deleteDeviceSnapshot(id: UUID) throws {
        devices.removeAll { $0.id == id }
    }
}

private final class SnapshotReadingStore: ReadingStoring, @unchecked Sendable {
    private var readings: [DeviceReading]

    init(_ readings: [DeviceReading]) {
        self.readings = readings
    }

    func saveReadings(_ readings: [DeviceReading]) throws {
        self.readings = readings
    }

    func loadReadings() throws -> [DeviceReading] {
        readings
    }

    func deleteReading(deviceID: UUID) throws {
        readings.removeAll { $0.deviceID == deviceID }
    }
}

private func data(_ hex: String) -> Data {
    var bytes = Data()
    var index = hex.startIndex

    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        bytes.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }

    return bytes
}
