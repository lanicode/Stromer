import ActivityKit
import CoreBluetooth
import Foundation
import Observation
import StromerScanner
import WidgetKit

enum BluetoothAuthorizationStatus: Equatable {
    case allowed
    case denied
    case restricted
    case notDetermined
    case unknown

    static var current: BluetoothAuthorizationStatus {
        switch CBManager.authorization {
        case .allowedAlways:
            return .allowed
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    var title: String {
        switch self {
        case .allowed:
            return "Erlaubt"
        case .denied:
            return "Abgelehnt"
        case .restricted:
            return "Eingeschränkt"
        case .notDetermined:
            return "Noch nicht gefragt"
        case .unknown:
            return "Unbekannt"
        }
    }

    var needsSettingsAction: Bool {
        self == .denied || self == .restricted
    }
}

enum DeviceRegistrationKind: String, CaseIterable, Identifiable {
    case smartShunt
    case smartSolar
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartShunt:
            return "SmartShunt / BMV"
        case .smartSolar:
            return "SmartSolar / MPPT"
        case .other:
            return "Andere"
        }
    }

    var recordType: UInt8? {
        switch self {
        case .smartShunt:
            return 0x02
        case .smartSolar:
            return 0x01
        case .other:
            return nil
        }
    }
}

@MainActor
@Observable
final class StromerAppViewModel {
    let store: VictronStore

    private(set) var registeredDevices: [RegisteredDevice] = []
    private(set) var scannerState: ScannerState = .idle
    private(set) var bluetoothAuthorization: BluetoothAuthorizationStatus = .current
    private(set) var lastErrorMessage: String?
    private(set) var activeLiveActivityDeviceIDs: Set<UUID> = []

    @ObservationIgnored private let registry: DeviceRegistry
    @ObservationIgnored private let keychainStore: any KeychainStoring
    @ObservationIgnored private let scannerService: ScannerService
    @ObservationIgnored private let liveActivityService: LiveActivityService<ActivityKitActivityClient>
    @ObservationIgnored private let deviceSnapshotStore: (any RegisteredDeviceSnapshotStoring)?
    @ObservationIgnored private let metadataDefaults: UserDefaults
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var liveActivityUpdateTokensByDeviceID: [UUID: LiveActivityUpdateToken] = [:]
    @ObservationIgnored private let metadataKey = "com.lanicode.StromerApp.registered-devices.metadata"
    @ObservationIgnored private let legacyMetadataKey = StromerIdentifiers.registeredDevicesStoreKey

    private init(
        registry: DeviceRegistry,
        store: VictronStore,
        scanner: any BLEScanning,
        keychainStore: any KeychainStoring,
        liveActivityService: LiveActivityService<ActivityKitActivityClient>,
        deviceSnapshotStore: (any RegisteredDeviceSnapshotStoring)?,
        metadataDefaults: UserDefaults,
        initialErrorMessage: String? = nil
    ) {
        self.registry = registry
        self.store = store
        self.keychainStore = keychainStore
        self.liveActivityService = liveActivityService
        self.deviceSnapshotStore = deviceSnapshotStore
        self.metadataDefaults = metadataDefaults
        self.scannerService = ScannerService(
            scanner: scanner,
            registry: registry,
            store: store
        )
        self.lastErrorMessage = initialErrorMessage
    }

    static func live() -> StromerAppViewModel {
        let readingStore: AppGroupReadingStore?
        var initialError: String?

        do {
            readingStore = try AppGroupReadingStore(
                suiteName: StromerIdentifiers.appGroup
            )
        } catch {
            readingStore = nil
            initialError = "App-Group-Speicher ist nicht verfügbar."
        }

        let store = VictronStore(readingStore: readingStore)
        do {
            try store.loadPersistedReadings()
        } catch {
            initialError = "Letzte Live-Werte konnten nicht geladen werden."
        }

        let registry = DeviceRegistry()
        let scanner = CoreBluetoothScanner()
        let keychainStore = KeychainStore(
            service: StromerIdentifiers.keychainService,
            accessGroup: nil
        )
        let liveActivityService = LiveActivityService(
            client: ActivityKitActivityClient()
        )
        let deviceSnapshotStore = try? AppGroupDeviceSnapshotStore(
            suiteName: StromerIdentifiers.appGroup
        )
        let defaults = UserDefaults(suiteName: StromerIdentifiers.appGroup) ?? .standard

        let model = StromerAppViewModel(
            registry: registry,
            store: store,
            scanner: scanner,
            keychainStore: keychainStore,
            liveActivityService: liveActivityService,
            deviceSnapshotStore: deviceSnapshotStore,
            metadataDefaults: defaults,
            initialErrorMessage: initialError
        )
        model.loadRegisteredDevices()
        model.refreshRuntimeState()
        return model
    }

    func start() async {
        startMonitoringIfNeeded()
        await scannerService.start()
        refreshRuntimeState()
    }

    func stopScanner() async {
        await scannerService.stop()
        refreshRuntimeState()
    }

    func restartScanner() async {
        await scannerService.stop()
        try? await Task.sleep(for: .milliseconds(350))
        await scannerService.start()
        refreshRuntimeState()
    }

    func registerDevice(
        name: String,
        advertisementKeyHex: String,
        kind: DeviceRegistrationKind
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppViewModelError.invalidName
        }

        guard let key = Data(hexString: advertisementKeyHex), key.count == 16 else {
            throw AppViewModelError.invalidKey
        }

        let id = UUID()
        try keychainStore.saveKey(key, for: id.uuidString)

        var device = try registry.register(
            id: id,
            name: trimmedName,
            advertisementKey: key
        )
        device.recordType = kind.recordType
        registry.upsert(device)
        registeredDevices = registry.devices
        persistRegisteredDevices()
        refreshRuntimeState()
    }

    func deleteDevice(id: UUID) {
        registry.replaceDevices(registry.devices.filter { $0.id != id })
        try? keychainStore.deleteKey(for: id.uuidString)
        try? store.removeReading(deviceID: id)
        Task {
            await liveActivityService.end(for: id)
            liveActivityUpdateTokensByDeviceID.removeValue(forKey: id)
            refreshLiveActivityState()
        }
        registeredDevices = registry.devices
        persistRegisteredDevices()
        refreshRuntimeState()
    }

    func device(id: UUID) -> RegisteredDevice? {
        registry.device(id: id)
    }

    func refreshRuntimeState() {
        bluetoothAuthorization = .current
        scannerState = scannerService.state
        refreshLiveActivityState()

        if let lastError = scannerService.lastError {
            lastErrorMessage = message(for: lastError)
        }

        let currentDevices = registry.devices
        if currentDevices != registeredDevices {
            registeredDevices = currentDevices
            persistRegisteredDevices()
        }

        try? store.recalculateFreshness()
    }

    func isLiveActivityActive(for deviceID: UUID) -> Bool {
        liveActivityService.hasActiveActivity(for: deviceID)
    }

    func startLiveActivity(for deviceID: UUID) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw AppViewModelError.liveActivitiesDisabled
        }

        guard let device = registry.device(id: deviceID) else {
            throw AppViewModelError.deviceMissing
        }

        guard let reading = store.reading(for: deviceID) else {
            throw AppViewModelError.noReading
        }

        _ = try await liveActivityService.start(for: device, reading: reading)
        liveActivityUpdateTokensByDeviceID[deviceID] = LiveActivityUpdateToken(reading: reading)
        refreshLiveActivityState()
    }

    func endLiveActivity(for deviceID: UUID) async {
        await liveActivityService.end(for: deviceID)
        liveActivityUpdateTokensByDeviceID.removeValue(forKey: deviceID)
        refreshLiveActivityState()
    }

    private func startMonitoringIfNeeded() {
        guard monitorTask == nil else {
            return
        }

        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshRuntimeState()
                await self?.updateActiveLiveActivitiesIfNeeded()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func updateActiveLiveActivitiesIfNeeded() async {
        for deviceID in liveActivityService.activeDeviceIDs {
            guard let reading = store.reading(for: deviceID) else {
                continue
            }

            let token = LiveActivityUpdateToken(reading: reading)
            guard liveActivityUpdateTokensByDeviceID[deviceID] != token else {
                continue
            }

            await liveActivityService.update(for: deviceID, reading: reading)
            liveActivityUpdateTokensByDeviceID[deviceID] = token
        }

        refreshLiveActivityState()
    }

    private func refreshLiveActivityState() {
        activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs
    }

    private func loadRegisteredDevices() {
        if let deviceSnapshotStore,
           let snapshots = try? deviceSnapshotStore.loadDeviceSnapshots(),
           !snapshots.isEmpty {
            let devices = snapshots.compactMap { item -> RegisteredDevice? in
                guard let key = try? keychainStore.loadKey(for: item.id.uuidString) else {
                    return nil
                }
                return item.registeredDevice(advertisementKey: key)
            }
            registry.replaceDevices(devices)
            registeredDevices = devices
            return
        }

        guard let data = metadataDefaults.data(forKey: metadataKey)
            ?? metadataDefaults.data(forKey: legacyMetadataKey) else {
            registeredDevices = []
            return
        }

        do {
            let metadata = try JSONDecoder().decode(
                [RegisteredDeviceMetadata].self,
                from: data
            )
            let devices = metadata.compactMap { item -> RegisteredDevice? in
                guard let key = try? keychainStore.loadKey(for: item.id.uuidString) else {
                    return nil
                }
                return item.registeredDevice(advertisementKey: key)
            }
            registry.replaceDevices(devices)
            registeredDevices = devices
            persistRegisteredDevices()
        } catch {
            lastErrorMessage = "Registrierte Geräte konnten nicht geladen werden."
        }
    }

    private func persistRegisteredDevices() {
        do {
            let snapshots = registry.devices.map(RegisteredDeviceSnapshot.init)
            if let deviceSnapshotStore {
                try deviceSnapshotStore.saveDeviceSnapshots(snapshots)
            } else {
                let metadata = registry.devices.map(RegisteredDeviceMetadata.init)
                let data = try JSONEncoder().encode(metadata)
                metadataDefaults.set(data, forKey: metadataKey)
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastErrorMessage = "Registrierte Geräte konnten nicht gespeichert werden."
        }
    }

    private func message(for error: ScannerError) -> String {
        switch error {
        case .invalidAdvertisementKeyLength:
            return "Der Advertisement Key muss 32 Hex-Zeichen lang sein."
        case .noMatchingDevice:
            return "Kein registriertes Gerät passt zu diesem Advertisement."
        case .ambiguousDeviceMatch:
            return "Mehrere Geräte passen zum empfangenen Advertisement."
        case .persistenceFailed:
            return "Live-Werte konnten nicht gespeichert werden."
        case .keychainFailed:
            return "Der Keychain-Zugriff ist fehlgeschlagen."
        case .appGroupUnavailable:
            return "Der App-Group-Speicher ist nicht verfügbar."
        }
    }
}

private enum AppViewModelError: LocalizedError {
    case invalidName
    case invalidKey
    case deviceMissing
    case noReading
    case liveActivitiesDisabled

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Bitte gib einen Gerätenamen ein."
        case .invalidKey:
            return "Der Advertisement Key muss exakt 32 Hex-Zeichen enthalten."
        case .deviceMissing:
            return "Dieses Gerät ist nicht mehr registriert."
        case .noReading:
            return "Für dieses Gerät gibt es noch keinen Live-Wert."
        case .liveActivitiesDisabled:
            return "Live Activities sind auf diesem iPhone deaktiviert."
        }
    }
}

private struct LiveActivityUpdateToken: Equatable {
    let readingID: UUID
    let timestamp: Date
    let freshness: DeviceFreshness

    init(reading: DeviceReading) {
        self.readingID = reading.id
        self.timestamp = reading.timestamp
        self.freshness = reading.freshness
    }
}

private struct RegisteredDeviceMetadata: Codable {
    let id: UUID
    let name: String
    let peripheralID: UUID?
    let localName: String?
    let productID: UInt16?
    let recordType: UInt8?
    let lastSeenAt: Date?
    let lastRSSI: Int?

    init(device: RegisteredDevice) {
        self.id = device.id
        self.name = device.name
        self.peripheralID = device.peripheralID
        self.localName = device.localName
        self.productID = device.productID
        self.recordType = device.recordType
        self.lastSeenAt = device.lastSeenAt
        self.lastRSSI = device.lastRSSI
    }

    func registeredDevice(advertisementKey: Data) -> RegisteredDevice {
        RegisteredDevice(
            id: id,
            name: name,
            advertisementKey: advertisementKey,
            peripheralID: peripheralID,
            localName: localName,
            productID: productID,
            recordType: recordType,
            lastSeenAt: lastSeenAt,
            lastRSSI: lastRSSI
        )
    }
}

private extension Data {
    init?(hexString: String) {
        let normalized = DeviceKeyValidator.normalized(hexString)
        guard DeviceKeyValidator.isValid(normalized) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(normalized.count / 2)

        var index = normalized.startIndex
        while index < normalized.endIndex {
            let nextIndex = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        self = Data(bytes)
    }
}
