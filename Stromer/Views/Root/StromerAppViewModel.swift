import ActivityKit
import CoreBluetooth
import Foundation
import Observation
import StromerScanner
import VictronParser

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
    private(set) var discoveredDevices: [DiscoveredDevice] = []

    @ObservationIgnored private let registry: DeviceRegistry
    @ObservationIgnored private let discoveryStore: DiscoveryStore
    @ObservationIgnored private let keychainStore: any KeychainStoring
    @ObservationIgnored private let scannerService: ScannerService
    @ObservationIgnored let historyStore: (any HistoryStore)?
    @ObservationIgnored let notificationSettings: NotificationSettings
    @ObservationIgnored let notificationCoordinator: NotificationCoordinator
    @ObservationIgnored let sunsetService: SunsetService
    @ObservationIgnored let dailyInsightScheduler: DailyInsightScheduler?
    @ObservationIgnored private let liveActivityService: LiveActivityService<ActivityKitActivityClient>
    @ObservationIgnored let widgetRefreshCoordinator: WidgetRefreshCoordinator
    @ObservationIgnored private let deviceSnapshotStore: (any RegisteredDeviceSnapshotStoring)?
    @ObservationIgnored private let metadataDefaults: UserDefaults
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var lastScanRecoveryAt: Date?
    @ObservationIgnored private var liveActivityUpdateTokensByDeviceID: [UUID: LiveActivityUpdateToken] = [:]
    @ObservationIgnored private let metadataKey = "com.lanicode.StromerApp.registered-devices.metadata"
    @ObservationIgnored private let legacyMetadataKey = StromerIdentifiers.registeredDevicesStoreKey

    private init(
        registry: DeviceRegistry,
        store: VictronStore,
        scanner: any BLEScanning,
        discoveryStore: DiscoveryStore,
        keychainStore: any KeychainStoring,
        historyStore: (any HistoryStore)?,
        notificationSettings: NotificationSettings,
        notificationCoordinator: NotificationCoordinator,
        sunsetService: SunsetService,
        dailyInsightScheduler: DailyInsightScheduler?,
        liveActivityService: LiveActivityService<ActivityKitActivityClient>,
        widgetRefreshCoordinator: WidgetRefreshCoordinator? = nil,
        deviceSnapshotStore: (any RegisteredDeviceSnapshotStoring)?,
        metadataDefaults: UserDefaults,
        initialErrorMessage: String? = nil
    ) {
        let widgetRefreshCoordinator = widgetRefreshCoordinator ?? WidgetRefreshCoordinator()
        self.registry = registry
        self.store = store
        self.discoveryStore = discoveryStore
        self.keychainStore = keychainStore
        self.historyStore = historyStore
        self.notificationSettings = notificationSettings
        self.notificationCoordinator = notificationCoordinator
        self.sunsetService = sunsetService
        self.dailyInsightScheduler = dailyInsightScheduler
        self.liveActivityService = liveActivityService
        self.widgetRefreshCoordinator = widgetRefreshCoordinator
        self.deviceSnapshotStore = deviceSnapshotStore
        self.metadataDefaults = metadataDefaults
        self.scannerService = ScannerService(
            scanner: scanner,
            registry: registry,
            store: store,
            discoveryStore: discoveryStore,
            historyStore: historyStore as? any DeviceReadingHistoryStoring,
            readingObserver: { reading in
                Task { @MainActor in
                    await notificationCoordinator.evaluate(reading: reading)
                }
            },
            onReadingUpdated: { _ in
                widgetRefreshCoordinator.requestReload(reason: .reading)
            }
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
        let discoveryStore = DiscoveryStore(registeredDevices: { registry.devices })
        let scanner = CoreBluetoothScanner()
        let keychainStore = KeychainStore(
            service: StromerIdentifiers.keychainService,
            accessGroup: nil
        )
        let historyStore: (any HistoryStore)?
        do {
            historyStore = try SwiftDataHistoryStore()
        } catch {
            historyStore = nil
            print("History store init failed: \(error)")
        }
        let notificationSettings = NotificationSettings()
        let sunsetService = SunsetService()
        let notificationCoordinator = NotificationCoordinator(
            settings: notificationSettings
        )
        let dailyInsightScheduler = historyStore.map {
            DailyInsightScheduler(
                settings: notificationSettings,
                sunsetService: sunsetService,
                historyStore: $0
            )
        }
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
            discoveryStore: discoveryStore,
            keychainStore: keychainStore,
            historyStore: historyStore,
            notificationSettings: notificationSettings,
            notificationCoordinator: notificationCoordinator,
            sunsetService: sunsetService,
            dailyInsightScheduler: dailyInsightScheduler,
            liveActivityService: liveActivityService,
            deviceSnapshotStore: deviceSnapshotStore,
            metadataDefaults: defaults,
            initialErrorMessage: initialError
        )
        model.loadRegisteredDevices()
        model.refreshRuntimeState()
        Task { @MainActor in
            await model.dailyInsightScheduler?.reschedule()
        }
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
        await scannerService.restartScan()
        refreshRuntimeState()
    }

    func resumeForeground() async {
        do {
            try store.loadPersistedReadings()
        } catch {
            lastErrorMessage = "Letzte Live-Werte konnten nicht geladen werden."
        }

        lastScanRecoveryAt = Date()
        await scannerService.restartScan(delay: .milliseconds(150))
        refreshRuntimeState()
        widgetRefreshCoordinator.requestReload(reason: .foreground)
    }

    func runOpportunisticAggregation() async {
        guard let historyStore else {
            return
        }

        await historyStore.aggregateLiveToMinute()
        await historyStore.aggregateMinuteToDaily()
    }

    var latestReadingTimestamps: [UUID: Date] {
        Dictionary(uniqueKeysWithValues: registeredDevices.compactMap { device in
            guard let timestamp = store.reading(for: device.id)?.timestamp ?? device.lastSeenAt else {
                return nil
            }
            return (device.id, timestamp)
        })
    }

    func checkDeviceLossNotifications() async {
        await notificationCoordinator.checkDeviceLoss(
            registeredDevices: registeredDevices,
            latestReadings: latestReadingTimestamps
        )
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

    func registerDiscoveredDevice(
        _ discoveredDevice: DiscoveredDevice,
        name: String,
        advertisementKeyHex: String
    ) throws {
        guard discoveredDevice.supportStatus != .outOfScope else {
            throw AppViewModelError.unsupportedDiscoveryDevice
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppViewModelError.invalidName
        }

        guard let key = Data(hexString: advertisementKeyHex), key.count == 16 else {
            throw AppViewModelError.invalidKey
        }

        guard let header = DiscoveryHeaderParser.parseHeader(
            manufacturerData: discoveredDevice.manufacturerData
        ),
        header.productID == discoveredDevice.productID,
        header.recordType == discoveredDevice.recordType else {
            throw AppViewModelError.discoveredAdvertisementExpired
        }

        if discoveredDevice.supportStatus == .supported {
            guard key.first == discoveredDevice.keyCheckByte else {
                throw AppViewModelError.wrongAdvertisementKey
            }

            guard case .success = parseVictronAdvertisement(
                manufacturerData: discoveredDevice.manufacturerData,
                key: key
            ) else {
                throw AppViewModelError.wrongAdvertisementKey
            }
        }

        let id = UUID()
        try keychainStore.saveKey(key, for: id.uuidString)

        var device = try registry.register(
            id: id,
            name: trimmedName,
            advertisementKey: key
        )
        device.peripheralID = discoveredDevice.peripheralID
        device.localName = discoveredDevice.localName
        device.productID = discoveredDevice.productID
        device.recordType = discoveredDevice.recordType
        device.lastSeenAt = discoveredDevice.lastSeenAt
        device.lastRSSI = discoveredDevice.rssi
        registry.upsert(device)
        registeredDevices = registry.devices
        persistRegisteredDevices()
        refreshDiscovery()
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
        persistRegisteredDevices(reloadReason: .deviceDeleted)
        refreshRuntimeState()
    }

    func device(id: UUID) -> RegisteredDevice? {
        registry.device(id: id)
    }

    func refreshRuntimeState() {
        bluetoothAuthorization = .current
        scannerState = scannerService.state
        refreshLiveActivityState()
        refreshDiscovery()

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

    var canUseDiscovery: Bool {
        bluetoothAuthorization == .allowed
            && scannerState != .unauthorized
            && scannerState != .off
            && scannerState != .unsupported
    }

    func refreshDiscovery() {
        discoveredDevices = discoveryStore.currentDevices()
    }

    func clearDiscovery() {
        discoveryStore.removeAll()
        discoveredDevices = []
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
                await self?.recoverScannerIfNeeded()
                await self?.updateActiveLiveActivitiesIfNeeded()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func recoverScannerIfNeeded() async {
        guard scannerState == .scanning, !registeredDevices.isEmpty else {
            return
        }

        let now = Date()
        if let lastScanRecoveryAt,
           now.timeIntervalSince(lastScanRecoveryAt) < 90 {
            return
        }

        let latestActivityDates = registeredDevices.compactMap { device in
            store.reading(for: device.id)?.timestamp ?? device.lastSeenAt
        }

        guard !latestActivityDates.contains(where: {
            now.timeIntervalSince($0) < DeviceFreshness.freshUpperBound
        }) else {
            return
        }

        lastScanRecoveryAt = now
        await scannerService.restartScan(delay: .milliseconds(150))
        refreshRuntimeState()
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

    private func persistRegisteredDevices(
        reloadReason: WidgetRefreshCoordinator.ReloadReason = .deviceRegistered
    ) {
        do {
            let snapshots = registry.devices.map(RegisteredDeviceSnapshot.init)
            if let deviceSnapshotStore {
                try deviceSnapshotStore.saveDeviceSnapshots(snapshots)
            } else {
                let metadata = registry.devices.map(RegisteredDeviceMetadata.init)
                let data = try JSONEncoder().encode(metadata)
                metadataDefaults.set(data, forKey: metadataKey)
            }
            widgetRefreshCoordinator.requestReload(reason: reloadReason)
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
    case wrongAdvertisementKey
    case discoveredAdvertisementExpired
    case unsupportedDiscoveryDevice

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
        case .wrongAdvertisementKey:
            return "Dieser Advertisement Key passt nicht zum zuletzt empfangenen Gerät."
        case .discoveredAdvertisementExpired:
            return "Das zuletzt empfangene Advertisement ist nicht mehr verfügbar. Bitte starte die Suche erneut."
        case .unsupportedDiscoveryDevice:
            return "Dieses Gerät wird derzeit nicht unterstützt."
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
