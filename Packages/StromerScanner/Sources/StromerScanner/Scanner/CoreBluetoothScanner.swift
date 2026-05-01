import CoreBluetooth
import Foundation

public final class CoreBluetoothScanner: NSObject, BLEScanning, RestoredPeripheralProviding, @unchecked Sendable {
    public let stateUpdates: AsyncStream<ScannerState>
    public let advertisements: AsyncStream<RawAdvertisement>
    public let restoredPeripheralIDs: AsyncStream<[UUID]>

    private let stateContinuation: AsyncStream<ScannerState>.Continuation
    private let advertisementContinuation: AsyncStream<RawAdvertisement>.Continuation
    private let restoredPeripheralContinuation: AsyncStream<[UUID]>.Continuation

    private var central: CBCentralManager!
    private var shouldScan = false

    public override init() {
        var stateContinuation: AsyncStream<ScannerState>.Continuation!
        var advertisementContinuation: AsyncStream<RawAdvertisement>.Continuation!
        var restoredPeripheralContinuation: AsyncStream<[UUID]>.Continuation!

        self.stateUpdates = AsyncStream { continuation in
            stateContinuation = continuation
        }
        self.advertisements = AsyncStream { continuation in
            advertisementContinuation = continuation
        }
        self.restoredPeripheralIDs = AsyncStream { continuation in
            restoredPeripheralContinuation = continuation
        }
        self.stateContinuation = stateContinuation
        self.advertisementContinuation = advertisementContinuation
        self.restoredPeripheralContinuation = restoredPeripheralContinuation

        super.init()

        self.central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey:
                    StromerIdentifiers.scannerRestoreIdentifier
            ]
        )
    }

    public func startScan() async {
        await MainActor.run {
            shouldScan = true
            startScanIfPossible()
        }
    }

    public func stopScan() async {
        await MainActor.run {
            shouldScan = false
            if central.isScanning {
                central.stopScan()
            }
            stateContinuation.yield(.idle)
        }
    }

    private func startScanIfPossible() {
        guard central.state == .poweredOn else {
            return
        }

        guard !central.isScanning else {
            return
        }

        // Background delivery is opportunistic for Victron Instant Readout:
        // Apple requires service UUID filters for reliable background scans,
        // while Victron's usable data is exposed through Manufacturer Data.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        stateContinuation.yield(.scanning)
    }

    private static func isVictronManufacturerData(_ data: Data) -> Bool {
        let bytes = Array(data)
        return bytes.count >= 3
            && bytes[0] == 0xE1
            && bytes[1] == 0x02
            && bytes[2] == 0x10
    }
}

extension CoreBluetoothScanner: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = ScannerState(centralState: central.state)
        stateContinuation.yield(state)

        if central.state == .poweredOn {
            startScanIfPossible()
        } else if central.isScanning {
            central.stopScan()
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        restoredPeripheralContinuation.yield(peripherals?.map(\.identifier) ?? [])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              Self.isVictronManufacturerData(manufacturerData) else {
            return
        }

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name

        advertisementContinuation.yield(RawAdvertisement(
            peripheralID: peripheral.identifier,
            localName: localName,
            manufacturerData: manufacturerData,
            rssi: RSSI.intValue,
            timestamp: Date()
        ))
    }
}

private extension ScannerState {
    init(centralState: CBManagerState) {
        switch centralState {
        case .unknown:
            self = .unknown
        case .resetting:
            self = .resetting
        case .unsupported:
            self = .unsupported
        case .unauthorized:
            self = .unauthorized
        case .poweredOff:
            self = .off
        case .poweredOn:
            self = .idle
        @unknown default:
            self = .unknown
        }
    }
}
