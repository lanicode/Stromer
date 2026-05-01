import Foundation

public struct StromerWidgetSnapshotProvider: Sendable {
    private let deviceStore: any RegisteredDeviceSnapshotStoring
    private let readingStore: any ReadingStoring
    private let nowProvider: @Sendable () -> Date
    private let reloadInterval: TimeInterval

    public init(
        deviceStore: any RegisteredDeviceSnapshotStoring,
        readingStore: any ReadingStoring,
        now: @escaping @Sendable () -> Date = Date.init,
        reloadInterval: TimeInterval = 30 * 60
    ) {
        self.deviceStore = deviceStore
        self.readingStore = readingStore
        self.nowProvider = now
        self.reloadInterval = reloadInterval
    }

    public static func appGroup(
        now: @escaping @Sendable () -> Date = Date.init
    ) throws -> StromerWidgetSnapshotProvider {
        try StromerWidgetSnapshotProvider(
            deviceStore: AppGroupDeviceSnapshotStore(),
            readingStore: AppGroupReadingStore(),
            now: now
        )
    }

    public func deviceOptions() throws -> [StromerWidgetDeviceOption] {
        try deviceStore.loadDeviceSnapshots()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { StromerWidgetDeviceOption(id: $0.id, name: $0.name) }
    }

    public func snapshot(
        selectedDeviceID: UUID?,
        maxDevices: Int = 2
    ) -> StromerWidgetSnapshot {
        let now = nowProvider()

        do {
            let devices = try deviceStore.loadDeviceSnapshots()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let readings = try readingStore.loadReadings()
            return makeSnapshot(
                date: now,
                devices: devices,
                readings: readings,
                selectedDeviceID: selectedDeviceID,
                maxDevices: maxDevices
            )
        } catch {
            return StromerWidgetSnapshot(
                date: now,
                devices: [],
                status: .noDevices,
                message: "Widget-Daten nicht verfügbar"
            )
        }
    }

    public func timeline(
        selectedDeviceID: UUID?,
        maxDevices: Int = 2
    ) -> StromerWidgetTimelineSnapshot {
        let snapshot = snapshot(selectedDeviceID: selectedDeviceID, maxDevices: maxDevices)
        return StromerWidgetTimelineSnapshot(
            entries: [snapshot],
            reloadAfter: snapshot.date.addingTimeInterval(reloadInterval)
        )
    }

    private func makeSnapshot(
        date: Date,
        devices: [RegisteredDeviceSnapshot],
        readings: [DeviceReading],
        selectedDeviceID: UUID?,
        maxDevices: Int
    ) -> StromerWidgetSnapshot {
        guard !devices.isEmpty else {
            return StromerWidgetSnapshot(
                date: date,
                devices: [],
                status: .noDevices,
                message: "Gerät in Stromer hinzufügen"
            )
        }

        let selectedDevices: [RegisteredDeviceSnapshot]
        if let selectedDeviceID {
            guard let selected = devices.first(where: { $0.id == selectedDeviceID }) else {
                return StromerWidgetSnapshot(
                    date: date,
                    devices: [],
                    status: .deviceMissing,
                    message: "Gerät nicht mehr vorhanden"
                )
            }

            let remaining = devices.filter { $0.id != selectedDeviceID }
            selectedDevices = Array(([selected] + remaining).prefix(max(1, maxDevices)))
        } else {
            selectedDevices = Array(devices.prefix(max(1, maxDevices)))
        }

        let readingsByID = Dictionary(uniqueKeysWithValues: readings.map { ($0.deviceID, $0) })
        let snapshots = selectedDevices.map { device in
            deviceSnapshot(device: device, reading: readingsByID[device.id], now: date)
        }

        return StromerWidgetSnapshot(
            date: date,
            devices: snapshots,
            status: .ready,
            message: ""
        )
    }

    private func deviceSnapshot(
        device: RegisteredDeviceSnapshot,
        reading: DeviceReading?,
        now: Date
    ) -> StromerWidgetDeviceSnapshot {
        let effectiveFreshness = DeviceFreshness(
            lastSeenAt: reading?.timestamp ?? device.lastSeenAt,
            now: now
        )
        let summary = DeviceReadingPresentation.summary(
            reading: reading,
            fallbackRecordType: reading?.recordType ?? device.recordType
        )

        return StromerWidgetDeviceSnapshot(
            id: device.id,
            name: device.name,
            deviceTypeIcon: summary.deviceTypeIcon,
            deviceTypeTitle: summary.deviceTypeTitle,
            mainLabel: summary.label,
            mainValue: summary.displayValue,
            mainUnit: summary.unit,
            secondary: summary.secondary,
            lastUpdated: reading?.timestamp ?? device.lastSeenAt,
            relativeLastUpdated: relativeTime(reading?.timestamp ?? device.lastSeenAt, now: now),
            freshness: effectiveFreshness
        )
    }

    private func relativeTime(_ date: Date?, now: Date) -> String {
        guard let date else {
            return "noch nie"
        }

        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return "gerade eben"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "vor \(minutes) Min."
        }

        let hours = minutes / 60
        if hours < 24 {
            return "vor \(hours) Std."
        }

        let days = hours / 24
        return "vor \(days) Tagen"
    }
}
