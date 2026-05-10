import Foundation

public struct StromerWidgetSnapshotProvider: Sendable {
    /// Default offsets for widget timeline entries so relative timestamps can age without a fresh reload.
    public static let defaultTimelineEntryOffsets: [TimeInterval] = [
        0,
        5 * 60,
        10 * 60,
        20 * 60,
        30 * 60
    ]

    private let deviceStore: any RegisteredDeviceSnapshotStoring
    private let readingStore: any ReadingStoring
    private let nowProvider: @Sendable () -> Date
    private let reloadInterval: TimeInterval
    private let entryOffsets: [TimeInterval]

    /// Creates a snapshot provider for widget snapshots and timelines.
    public init(
        deviceStore: any RegisteredDeviceSnapshotStoring,
        readingStore: any ReadingStoring,
        now: @escaping @Sendable () -> Date = Date.init,
        reloadInterval: TimeInterval = 30 * 60,
        entryOffsets: [TimeInterval] = StromerWidgetSnapshotProvider.defaultTimelineEntryOffsets
    ) {
        self.deviceStore = deviceStore
        self.readingStore = readingStore
        self.nowProvider = now
        self.reloadInterval = reloadInterval
        self.entryOffsets = entryOffsets.isEmpty ? [0] : entryOffsets
    }

    /// Creates a snapshot provider backed by the shared app group stores.
    public static func appGroup(
        now: @escaping @Sendable () -> Date = Date.init,
        entryOffsets: [TimeInterval] = StromerWidgetSnapshotProvider.defaultTimelineEntryOffsets
    ) throws -> StromerWidgetSnapshotProvider {
        try StromerWidgetSnapshotProvider(
            deviceStore: AppGroupDeviceSnapshotStore(),
            readingStore: AppGroupReadingStore(),
            now: now,
            entryOffsets: entryOffsets
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
        snapshot(
            selectedDeviceID: selectedDeviceID,
            preferences: nil,
            maxDevices: maxDevices
        )
    }

    public func snapshot(
        selectedDeviceID: UUID?,
        preferences: StromerWidgetPreferences?,
        maxDevices: Int = 2
    ) -> StromerWidgetSnapshot {
        let now = nowProvider()

        do {
            let sourceData = try loadSnapshotSourceData()
            return makeSnapshot(
                date: now,
                devices: sourceData.devices,
                readings: sourceData.readings,
                selectedDeviceID: selectedDeviceID,
                preferences: preferences,
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
        timeline(
            selectedDeviceID: selectedDeviceID,
            preferences: nil,
            maxDevices: maxDevices
        )
    }

    public func timeline(
        selectedDeviceID: UUID?,
        preferences: StromerWidgetPreferences?,
        maxDevices: Int = 2
    ) -> StromerWidgetTimelineSnapshot {
        let now = nowProvider()
        let entries: [StromerWidgetSnapshot]

        do {
            let sourceData = try loadSnapshotSourceData()
            entries = makeTimelineEntries(
                now: now,
                devices: sourceData.devices,
                readings: sourceData.readings,
                selectedDeviceID: selectedDeviceID,
                preferences: preferences,
                maxDevices: maxDevices
            )
        } catch {
            entries = entryOffsets.map { offset in
                StromerWidgetSnapshot(
                    date: now.addingTimeInterval(offset),
                    devices: [],
                    status: .noDevices,
                    message: "Widget-Daten nicht verfügbar"
                )
            }
        }

        // Keep the reload request anchored to the generation time: later entries only age labels,
        // while fresh BLE-backed data should still be requested after the configured interval.
        return StromerWidgetTimelineSnapshot(
            entries: entries,
            reloadAfter: now.addingTimeInterval(reloadInterval)
        )
    }

    private struct SnapshotSourceData {
        let devices: [RegisteredDeviceSnapshot]
        let readings: [DeviceReading]
    }

    private func loadSnapshotSourceData() throws -> SnapshotSourceData {
        let devices = try deviceStore.loadDeviceSnapshots()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let readings = try readingStore.loadReadings()
        return SnapshotSourceData(devices: devices, readings: readings)
    }

    private func makeTimelineEntries(
        now: Date,
        devices: [RegisteredDeviceSnapshot],
        readings: [DeviceReading],
        selectedDeviceID: UUID?,
        preferences: StromerWidgetPreferences?,
        maxDevices: Int
    ) -> [StromerWidgetSnapshot] {
        entryOffsets.map { offset in
            makeSnapshot(
                date: now.addingTimeInterval(offset),
                devices: devices,
                readings: readings,
                selectedDeviceID: selectedDeviceID,
                preferences: preferences,
                maxDevices: maxDevices
            )
        }
    }

    private func makeSnapshot(
        date: Date,
        devices: [RegisteredDeviceSnapshot],
        readings: [DeviceReading],
        selectedDeviceID: UUID?,
        preferences: StromerWidgetPreferences?,
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
        if let preferences {
            selectedDevices = preferredDevices(
                from: devices,
                selectedDeviceID: selectedDeviceID,
                preferences: preferences,
                maxDevices: maxDevices
            )
        } else if let selectedDeviceID {
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

    private func preferredDevices(
        from devices: [RegisteredDeviceSnapshot],
        selectedDeviceID: UUID?,
        preferences: StromerWidgetPreferences,
        maxDevices: Int
    ) -> [RegisteredDeviceSnapshot] {
        let limit = max(1, maxDevices)

        switch preferences.mediumMode {
        case .automatic:
            if let selectedDeviceID,
               let selected = devices.first(where: { $0.id == selectedDeviceID }) {
                let remaining = devices.filter { $0.id != selectedDeviceID }
                return Array(([selected] + remaining).prefix(limit))
            }
            return Array(devices.prefix(limit))

        case .manual:
            let preferred = preferences.mediumDeviceIDs.compactMap { id in
                devices.first { $0.id == id }
            }
            let remaining = devices.filter { device in
                !preferred.contains { $0.id == device.id }
            }
            return Array((preferred + remaining).prefix(limit))

        case .battery:
            return focusedDevices(from: devices, matchingRecordType: 0x02, limit: limit)

        case .solar:
            return focusedDevices(from: devices, matchingRecordType: 0x01, limit: limit)

        case .dcDc:
            return focusedDevices(from: devices, matchingRecordType: 0x04, limit: limit)
        }
    }

    private func focusedDevices(
        from devices: [RegisteredDeviceSnapshot],
        matchingRecordType recordType: UInt8,
        limit: Int
    ) -> [RegisteredDeviceSnapshot] {
        let focused = devices.filter { $0.recordType == recordType }
        let remaining = devices.filter { $0.recordType != recordType }
        return Array((focused + remaining).prefix(limit))
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
