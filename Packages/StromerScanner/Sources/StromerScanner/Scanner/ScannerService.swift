import Foundation

@MainActor
public protocol DeviceReadingHistoryStoring: Sendable {
    func recordReading(_ reading: DeviceReading) async
}

@MainActor
public final class ScannerService {
    public private(set) var state: ScannerState = .idle
    public private(set) var lastError: ScannerError?

    private let scanner: any BLEScanning
    private let registry: DeviceRegistry
    private let store: VictronStore
    private let discoveryStore: DiscoveryStore?
    private let historyStore: (any DeviceReadingHistoryStoring)?
    private let readingObserver: (@MainActor @Sendable (DeviceReading) -> Void)?
    private let onReadingUpdated: (@MainActor @Sendable (DeviceReading) -> Void)?
    private var tasks: [Task<Void, Never>] = []

    public init(
        scanner: any BLEScanning,
        registry: DeviceRegistry,
        store: VictronStore,
        discoveryStore: DiscoveryStore? = nil,
        historyStore: (any DeviceReadingHistoryStoring)? = nil,
        readingObserver: (@MainActor @Sendable (DeviceReading) -> Void)? = nil,
        onReadingUpdated: (@MainActor @Sendable (DeviceReading) -> Void)? = nil
    ) {
        self.scanner = scanner
        self.registry = registry
        self.store = store
        self.discoveryStore = discoveryStore
        self.historyStore = historyStore
        self.readingObserver = readingObserver
        self.onReadingUpdated = onReadingUpdated
    }

    public func start() async {
        startObservingIfNeeded()
        await scanner.startScan()
    }

    public func stop() async {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        await scanner.stopScan()
        state = .idle
    }

    public func restartScan(delay: Duration = .milliseconds(350)) async {
        startObservingIfNeeded()
        await scanner.stopScan()
        try? await Task.sleep(for: delay)
        await scanner.startScan()
    }

    @discardableResult
    func handleAdvertisement(_ advertisement: RawAdvertisement) -> DeviceRegistryMatchResult {
        guard Self.isVictronInstantReadout(advertisement.manufacturerData) else {
            return .noMatch
        }

        discoveryStore?.update(rawAdvertisement: advertisement)

        let result = registry.match(advertisement)
        switch result {
        case let .matched(match):
            do {
                let reading = try store.update(
                    device: match.device,
                    record: match.record,
                    advertisement: match.advertisement
                )
                if let historyStore {
                    Task {
                        await historyStore.recordReading(reading)
                    }
                }
                readingObserver?(reading)
                onReadingUpdated?(reading)
                lastError = nil
            } catch {
                lastError = .persistenceFailed(String(describing: error))
                state = .failed(String(describing: error))
            }

        case .ambiguous:
            lastError = .ambiguousDeviceMatch
            state = .failed("Ambiguous Victron device match")

        case .noMatch:
            break
        }

        return result
    }

    static func isVictronInstantReadout(_ manufacturerData: Data) -> Bool {
        let bytes = Array(manufacturerData)

        if bytes.count >= 3,
           bytes[0] == 0xE1,
           bytes[1] == 0x02 {
            return bytes[2] == 0x10
        }

        return bytes.first == 0x10
    }

    private func startObservingIfNeeded() {
        guard tasks.isEmpty else {
            return
        }

        tasks.append(Task { [weak self, scanner] in
            for await state in scanner.stateUpdates {
                await MainActor.run {
                    self?.state = state
                }
            }
        })

        tasks.append(Task { [weak self, scanner] in
            for await advertisement in scanner.advertisements {
                await MainActor.run {
                    _ = self?.handleAdvertisement(advertisement)
                }
            }
        })
    }
}
