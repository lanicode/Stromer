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
    @ObservationIgnored private let deviceSnapshotStore: any RegisteredDeviceSnapshotStoring
    @ObservationIgnored private let liveActivityService: LiveActivityService<ActivityKitActivityClient>
    @ObservationIgnored private var scannerService: ScannerService!
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    private init(
        registry: DeviceRegistry,
        store: VictronStore,
        scanner: any BLEScanning,
        keychainStore: any KeychainStoring,
        deviceSnapshotStore: any RegisteredDeviceSnapshotStoring,
        liveActivityService: LiveActivityService<ActivityKitActivityClient>,
        initialErrorMessage: String? = nil
    ) {
        self.registry = registry
        self.store = store
        self.keychainStore = keychainStore
        self.deviceSnapshotStore = deviceSnapshotStore
        self.liveActivityService = liveActivityService
        self.lastErrorMessage = initialErrorMessage
        self.scannerService = ScannerService(
            scanner: scanner,
            registry: registry,
            store: store,
            onReadingUpdated: { [weak self] reading in
                self?.handleReadingUpdated(reading)
            }
        )
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
        let defaults = UserDefaults(suiteName: StromerIdentifiers.appGroup) ?? .standard
        let deviceSnapshotStore = AppGroupDeviceSnapshotStore(
            backing: DefaultsBackedKeyValueStore(defaults: defaults)
        )
        let liveActivityService = LiveActivityService(
            client: ActivityKitActivityClient()
        )

        let model = StromerAppViewModel(
            registry: registry,
            store: store,
            scanner: scanner,
            keychainStore: keychainStore,
            deviceSnapshotStore: deviceSnapshotStore,
            liveActivityService: liveActivityService,
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
            activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs
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
        activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs

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
        activeLiveActivityDeviceIDs.contains(deviceID)
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
        activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs
    }

    func endLiveActivity(for deviceID: UUID) async {
        await liveActivityService.end(for: deviceID)
        activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs
    }

    private func startMonitoringIfNeeded() {
        guard monitorTask == nil else {
            return
        }

        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshRuntimeState()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func loadRegisteredDevices() {
        do {
            let snapshots = try deviceSnapshotStore.loadDeviceSnapshots()
            let devices = snapshots.compactMap { item -> RegisteredDevice? in
                guard let key = try? keychainStore.loadKey(for: item.id.uuidString) else {
                    return nil
                }
                return item.registeredDevice(advertisementKey: key)
            }
            registry.replaceDevices(devices)
            registeredDevices = devices
        } catch {
            lastErrorMessage = "Registrierte Geräte konnten nicht geladen werden."
        }
    }

    private func persistRegisteredDevices() {
        do {
            try deviceSnapshotStore.saveDeviceSnapshots(
                registry.devices.map(RegisteredDeviceSnapshot.init)
            )
            WidgetCenter.shared.invalidateConfigurationRecommendations()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastErrorMessage = "Registrierte Geräte konnten nicht gespeichert werden."
        }
    }

    private func handleReadingUpdated(_ reading: DeviceReading) {
        WidgetCenter.shared.reloadAllTimelines()

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await liveActivityService.update(for: reading.deviceID, reading: reading)
            activeLiveActivityDeviceIDs = liveActivityService.activeDeviceIDs
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

private final class DefaultsBackedKeyValueStore: AppGroupKeyValueStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ value: Data?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
