import Foundation
@testable import StromerScanner
import XCTest

@MainActor
final class ScannerServiceTests: XCTestCase {
    func testMockScannerAdvertisementUpdatesStore() async throws {
        let scanner = MockBLEScanner()
        let registry = DeviceRegistry()
        let readingStore = InMemoryReadingStore()
        let store = VictronStore(readingStore: readingStore, now: { referenceDate })
        let service = ScannerService(scanner: scanner, registry: registry, store: store)
        try registry.register(name: "SmartShunt", advertisementKey: batteryKey)

        await service.start()
        scanner.emitAdvertisement(RawAdvertisement(
            peripheralID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            localName: "SmartShunt HT",
            manufacturerData: batteryAdvertisementWithCompanyID,
            rssi: -68,
            timestamp: referenceDate
        ))

        try await waitForStoreUpdate(store)

        XCTAssertEqual(store.latestReadings.count, 1)
        XCTAssertEqual(store.latestReadings.first?.name, "SmartShunt")
        XCTAssertEqual(store.latestReadings.first?.productID, 0xA389)
        XCTAssertEqual(try readingStore.loadReadings().count, 1)
        XCTAssertNil(service.lastError)
    }

    func testInvalidAdvertisementIsIgnored() async throws {
        let scanner = MockBLEScanner()
        let registry = DeviceRegistry()
        let store = VictronStore()
        let service = ScannerService(scanner: scanner, registry: registry, store: store)
        try registry.register(name: "SmartShunt", advertisementKey: batteryKey)

        await service.start()
        scanner.emitAdvertisement(RawAdvertisement(
            peripheralID: UUID(),
            localName: nil,
            manufacturerData: Data([0x00, 0x02, 0x10]),
            rssi: -80,
            timestamp: referenceDate
        ))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(store.latestReadings.isEmpty)
        XCTAssertNil(service.lastError)
    }

    func testStateUpdatesFlowThroughService() async throws {
        let scanner = MockBLEScanner()
        let service = ScannerService(
            scanner: scanner,
            registry: DeviceRegistry(),
            store: VictronStore()
        )

        await service.start()
        scanner.emitState(.off)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(service.state, .off)
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
private let batteryKey = data("aff4d0995b7d1e176c0c33ecb9e70dcd")
private let batteryAdvertisementWithCompanyID = data("e102100289a302b040af925d09a4d89aa0128bdef48c6298a9")

private final class MockBLEScanner: BLEScanning, @unchecked Sendable {
    let stateUpdates: AsyncStream<ScannerState>
    let advertisements: AsyncStream<RawAdvertisement>

    private let stateContinuation: AsyncStream<ScannerState>.Continuation
    private let advertisementContinuation: AsyncStream<RawAdvertisement>.Continuation

    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        var stateContinuation: AsyncStream<ScannerState>.Continuation!
        var advertisementContinuation: AsyncStream<RawAdvertisement>.Continuation!

        self.stateUpdates = AsyncStream { continuation in
            stateContinuation = continuation
        }
        self.advertisements = AsyncStream { continuation in
            advertisementContinuation = continuation
        }
        self.stateContinuation = stateContinuation
        self.advertisementContinuation = advertisementContinuation
    }

    func startScan() async {
        startCount += 1
    }

    func stopScan() async {
        stopCount += 1
    }

    func emitState(_ state: ScannerState) {
        stateContinuation.yield(state)
    }

    func emitAdvertisement(_ advertisement: RawAdvertisement) {
        advertisementContinuation.yield(advertisement)
    }
}

private final class InMemoryReadingStore: ReadingStoring, @unchecked Sendable {
    private var readings: [DeviceReading] = []

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

@MainActor
private func waitForStoreUpdate(_ store: VictronStore) async throws {
    for _ in 0..<20 {
        if !store.latestReadings.isEmpty {
            return
        }
        try await Task.sleep(nanoseconds: 25_000_000)
    }

    XCTFail("Timed out waiting for store update")
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
