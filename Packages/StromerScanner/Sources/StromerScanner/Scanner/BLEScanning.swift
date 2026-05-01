import Foundation

public protocol BLEScanning: Sendable {
    var stateUpdates: AsyncStream<ScannerState> { get }
    var advertisements: AsyncStream<RawAdvertisement> { get }

    func startScan() async
    func stopScan() async
}

public protocol RestoredPeripheralProviding: Sendable {
    var restoredPeripheralIDs: AsyncStream<[UUID]> { get }
}

public struct RawAdvertisement: Equatable, Sendable {
    public let peripheralID: UUID
    public let localName: String?
    public let manufacturerData: Data
    public let rssi: Int
    public let timestamp: Date

    public init(
        peripheralID: UUID,
        localName: String?,
        manufacturerData: Data,
        rssi: Int,
        timestamp: Date
    ) {
        self.peripheralID = peripheralID
        self.localName = localName
        self.manufacturerData = manufacturerData
        self.rssi = rssi
        self.timestamp = timestamp
    }
}
