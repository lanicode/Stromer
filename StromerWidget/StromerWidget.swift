import AppIntents
import StromerScanner
import SwiftUI
import WidgetKit

struct StromerDeviceEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Gerät")
    static var defaultQuery = StromerDeviceQuery()

    let id: String
    let name: String

    var uuid: UUID? {
        UUID(uuidString: id)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct StromerDeviceQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [String]) async throws -> [StromerDeviceEntity] {
        let entities = loadEntities()
        return entities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [StromerDeviceEntity] {
        loadEntities()
    }

    private func loadEntities() -> [StromerDeviceEntity] {
        do {
            let provider = try StromerWidgetSnapshotProvider.appGroup()
            return try provider.deviceOptions().map {
                StromerDeviceEntity(id: $0.id.uuidString, name: $0.name)
            }
        } catch {
            return []
        }
    }
}

struct StromerWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Stromer Gerät"
    static var description = IntentDescription("Wähle ein registriertes Victron-Gerät für das Widget.")

    @Parameter(title: "Gerät")
    var device: StromerDeviceEntity?
}

struct StromerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: StromerWidgetSnapshot
}

struct StromerWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StromerWidgetEntry {
        StromerWidgetEntry(
            date: .now,
            snapshot: .placeholder()
        )
    }

    func snapshot(
        for configuration: StromerWidgetConfigurationIntent,
        in context: Context
    ) async -> StromerWidgetEntry {
        entry(for: configuration, family: context.family)
    }

    func timeline(
        for configuration: StromerWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<StromerWidgetEntry> {
        let maxDevices = context.family == .systemMedium ? 2 : 1
        let selectedID = configuration.device?.uuid

        do {
            let timeline = try StromerWidgetSnapshotProvider.appGroup()
                .timeline(selectedDeviceID: selectedID, maxDevices: maxDevices)
            let entries = timeline.entries.map {
                StromerWidgetEntry(date: $0.date, snapshot: $0)
            }
            return Timeline(entries: entries, policy: .after(timeline.reloadAfter))
        } catch {
            let entry = StromerWidgetEntry(
                date: .now,
                snapshot: StromerWidgetSnapshot(
                    date: .now,
                    devices: [],
                    status: .noDevices,
                    message: "Widget-Daten nicht verfügbar"
                )
            )
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
        }
    }

    private func entry(
        for configuration: StromerWidgetConfigurationIntent,
        family: WidgetFamily
    ) -> StromerWidgetEntry {
        let maxDevices = family == .systemMedium ? 2 : 1
        let selectedID = configuration.device?.uuid
        let snapshot = (try? StromerWidgetSnapshotProvider.appGroup()
            .snapshot(selectedDeviceID: selectedID, maxDevices: maxDevices))
            ?? .placeholder()

        return StromerWidgetEntry(date: snapshot.date, snapshot: snapshot)
    }
}

struct StromerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StromerWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            case .accessoryCircular:
                circularAccessory
            case .accessoryRectangular:
                rectangularAccessory
            case .accessoryInline:
                inlineAccessory
            default:
                smallWidget
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var firstDevice: StromerWidgetDeviceSnapshot? {
        entry.snapshot.devices.first
    }

    @ViewBuilder
    private var smallWidget: some View {
        if let device = firstDevice {
            DeviceWidgetTile(device: device, compact: false)
                .padding()
        } else {
            PlaceholderWidgetView(message: entry.snapshot.message)
                .padding()
        }
    }

    @ViewBuilder
    private var mediumWidget: some View {
        if entry.snapshot.devices.isEmpty {
            PlaceholderWidgetView(message: entry.snapshot.message)
                .padding()
        } else {
            HStack(spacing: 12) {
                ForEach(entry.snapshot.devices.prefix(2)) { device in
                    DeviceWidgetTile(device: device, compact: true)

                    if device.id != entry.snapshot.devices.prefix(2).last?.id {
                        Divider()
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var circularAccessory: some View {
        if let device = firstDevice {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: device.deviceTypeIcon)
                        .font(.caption2)
                    Text("\(device.mainValue)\(device.mainUnit)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                }
                .opacity(device.isDimmed ? 0.55 : 1)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
            }
        }
    }

    @ViewBuilder
    private var rectangularAccessory: some View {
        if let device = firstDevice {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(device.mainValue) \(device.mainUnit)")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                Text(device.secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(device.isDimmed ? 0.55 : 1)
        } else {
            Text(entry.snapshot.message)
        }
    }

    @ViewBuilder
    private var inlineAccessory: some View {
        if let device = firstDevice {
            Text("\(device.name): \(device.mainValue) \(device.mainUnit)")
        } else {
            Text("Stromer: Gerät hinzufügen")
        }
    }
}

private struct DeviceWidgetTile: View {
    let device: StromerWidgetDeviceSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack(spacing: 6) {
                Image(systemName: device.deviceTypeIcon)
                    .foregroundStyle(.tint)
                Text(device.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.mainLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(device.mainValue)
                        .font(.system(size: compact ? 28 : 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(device.mainUnit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(device.secondary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 5) {
                Circle()
                    .fill(color(for: device.freshness))
                    .frame(width: 6, height: 6)
                Text(device.relativeLastUpdated)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .opacity(device.isDimmed ? 0.55 : 1)
    }

    private func color(for freshness: DeviceFreshness) -> Color {
        switch freshness {
        case .fresh:
            return .green
        case .delayed:
            return .yellow
        case .stale:
            return .orange
        case .missing:
            return .red
        }
    }
}

private struct PlaceholderWidgetView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("Stromer")
                .font(.headline)
            Text(message.isEmpty ? "Gerät in Stromer hinzufügen" : message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct StromerWidget: Widget {
    private let kind = "StromerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StromerWidgetConfigurationIntent.self,
            provider: StromerWidgetProvider()
        ) { entry in
            StromerWidgetView(entry: entry)
        }
        .configurationDisplayName("Stromer")
        .description("Zeigt die letzten Victron-Live-Werte aus Stromer.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    StromerWidget()
} timeline: {
    StromerWidgetEntry(date: .now, snapshot: .placeholder())
}
