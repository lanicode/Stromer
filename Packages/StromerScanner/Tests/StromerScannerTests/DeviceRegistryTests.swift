import Foundation
@testable import StromerScanner
import VictronParser
import XCTest

@MainActor
final class DeviceRegistryTests: XCTestCase {
    func testMatchesRegisteredDeviceByKey() throws {
        let registry = DeviceRegistry()
        let device = try registry.register(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "SmartShunt",
            advertisementKey: batteryKey
        )
        let peripheralID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let result = registry.match(RawAdvertisement(
            peripheralID: peripheralID,
            localName: "SmartShunt HT",
            manufacturerData: batteryAdvertisement,
            rssi: -61,
            timestamp: referenceDate
        ))

        guard case let .matched(match) = result else {
            return XCTFail("Expected a matched device")
        }

        XCTAssertEqual(match.device.id, device.id)
        XCTAssertEqual(match.device.peripheralID, peripheralID)
        XCTAssertEqual(match.device.localName, "SmartShunt HT")
        XCTAssertEqual(match.device.productID, 0xA389)
        XCTAssertEqual(match.device.recordType, 0x02)
        XCTAssertEqual(registry.device(id: device.id)?.peripheralID, peripheralID)
    }

    func testRebindsAfterPeripheralUUIDChanges() throws {
        let oldPeripheralID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let newPeripheralID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let deviceID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let registry = DeviceRegistry(devices: [
            RegisteredDevice(
                id: deviceID,
                name: "SmartShunt",
                advertisementKey: batteryKey,
                peripheralID: oldPeripheralID,
                productID: 0xA389,
                recordType: 0x02
            )
        ])

        let result = registry.match(RawAdvertisement(
            peripheralID: newPeripheralID,
            localName: nil,
            manufacturerData: batteryAdvertisement,
            rssi: -70,
            timestamp: referenceDate
        ))

        guard case let .matched(match) = result else {
            return XCTFail("Expected re-bind match")
        }

        XCTAssertEqual(match.device.id, deviceID)
        XCTAssertEqual(match.device.peripheralID, newPeripheralID)
        XCTAssertEqual(registry.device(id: deviceID)?.peripheralID, newPeripheralID)
    }

    func testAmbiguousFirstKeyByteResolvesWithParserValidationAndConstraints() {
        let correctID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let wrongID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        var wrongSameFirstByte = Data(repeating: 0, count: 16)
        wrongSameFirstByte[0] = batteryKey[0]

        let registry = DeviceRegistry(devices: [
            RegisteredDevice(
                id: correctID,
                name: "Correct SmartShunt",
                advertisementKey: batteryKey,
                productID: 0xA389,
                recordType: 0x02
            ),
            RegisteredDevice(
                id: wrongID,
                name: "Wrong MPPT",
                advertisementKey: wrongSameFirstByte,
                productID: 0xA042,
                recordType: 0x01
            )
        ])

        let result = registry.match(RawAdvertisement(
            peripheralID: UUID(),
            localName: nil,
            manufacturerData: batteryAdvertisement,
            rssi: -65,
            timestamp: referenceDate
        ))

        guard case let .matched(match) = result else {
            return XCTFail("Expected constrained parser validation to resolve match")
        }

        XCTAssertEqual(match.device.id, correctID)
    }

    func testAmbiguousMatchesRemainAmbiguous() {
        let registry = DeviceRegistry(devices: [
            RegisteredDevice(name: "A", advertisementKey: batteryKey),
            RegisteredDevice(name: "B", advertisementKey: batteryKey)
        ])

        let result = registry.match(RawAdvertisement(
            peripheralID: UUID(),
            localName: nil,
            manufacturerData: batteryAdvertisement,
            rssi: -65,
            timestamp: referenceDate
        ))

        XCTAssertEqual(result, .ambiguous)
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
private let batteryKey = data("aff4d0995b7d1e176c0c33ecb9e70dcd")
private let batteryAdvertisement = data("100289a302b040af925d09a4d89aa0128bdef48c6298a9")

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
