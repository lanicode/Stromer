import AppIntents
import StromerScanner
import SwiftUI
import WidgetKit

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
        let maxDevices = context.family == .systemMedium ? 3 : 1
        let selectedID = configuration.device?.uuid
        let preferences = context.family == .systemMedium ? mediumPreferences() : nil

        do {
            let timeline = try StromerWidgetSnapshotProvider.appGroup()
                .timeline(
                    selectedDeviceID: selectedID,
                    preferences: preferences,
                    maxDevices: maxDevices
                )
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
        let maxDevices = family == .systemMedium ? 3 : 1
        let selectedID = configuration.device?.uuid
        let preferences = family == .systemMedium ? mediumPreferences() : nil
        let snapshot = (try? StromerWidgetSnapshotProvider.appGroup()
            .snapshot(
                selectedDeviceID: selectedID,
                preferences: preferences,
                maxDevices: maxDevices
            ))
            ?? .placeholder()

        return StromerWidgetEntry(date: snapshot.date, snapshot: snapshot)
    }

    private func mediumPreferences() -> StromerWidgetPreferences {
        (try? AppGroupWidgetPreferenceStore().loadPreferences()) ?? .default
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
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var firstDevice: StromerWidgetDeviceSnapshot? {
        guard entry.snapshot.status == .ready else {
            return nil
        }

        return entry.snapshot.devices.first
    }

    @ViewBuilder
    private var widgetBackground: some View {
        switch family {
        case .systemSmall:
            WidgetConnectionBackground(status: widgetConnectionStatus)
        case .systemMedium:
            WidgetConnectionBackground(status: widgetConnectionStatus)
        default:
            Color.clear
        }
    }

    @ViewBuilder
    private var smallWidget: some View {
        if let device = firstDevice {
            DeviceWidgetTile(
                device: device,
                connectionStatus: WidgetConnectionStatus(device: device, now: entry.date)
            )
                .padding(14)
        } else {
            WidgetEmptyStateView(status: entry.snapshot.status, compact: false)
                .padding(14)
        }
    }

    @ViewBuilder
    private var mediumWidget: some View {
        if entry.snapshot.status != .ready || entry.snapshot.devices.isEmpty {
            WidgetEmptyStateView(status: entry.snapshot.status, compact: false)
                .padding(14)
        } else {
            MediumHeroWidget(
                devices: Array(entry.snapshot.devices.prefix(3)),
                connectionStatus: widgetConnectionStatus,
                lastUpdatedText: widgetLastUpdatedText
            )
                .padding(14)
        }
    }

    @ViewBuilder
    private var circularAccessory: some View {
        if let device = firstDevice {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    BoltWidgetGlyph(
                        size: 11,
                        fillColor: .primary,
                        strokeColor: .clear,
                        strokeWidth: 0
                    )
                    Text("\(device.mainValue)\(device.mainUnit)")
                        .font(.system(size: 13, weight: .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                }
                .opacity(device.isDimmed ? 0.55 : 1)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: WidgetEmptyStateContent(status: entry.snapshot.status).iconSystemName)
            }
        }
    }

    @ViewBuilder
    private var rectangularAccessory: some View {
        if let device = firstDevice {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text("\(device.mainValue) \(device.mainUnit)")
                    .font(.headline.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
                Text(device.secondary)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(device.isDimmed ? 0.55 : 1)
        } else {
            WidgetEmptyStateView(status: entry.snapshot.status, compact: true)
        }
    }

    @ViewBuilder
    private var inlineAccessory: some View {
        if let device = firstDevice {
            Text("Stromer · \(device.mainValue) \(device.mainUnit) · \(device.relativeLastUpdated)")
        } else {
            Text("Stromer · \(WidgetEmptyStateContent(status: entry.snapshot.status).title)")
        }
    }

    private var widgetConnectionStatus: WidgetConnectionStatus {
        WidgetConnectionStatus.aggregate(
            devices: entry.snapshot.devices,
            now: entry.date
        )
    }

    private var widgetLastUpdatedText: String {
        let devices = entry.snapshot.devices
        guard let oldest = devices.min(by: { lhs, rhs in
            (lhs.lastUpdated ?? .distantPast) < (rhs.lastUpdated ?? .distantPast)
        }) else {
            return "Noch keine Daten"
        }

        return oldest.relativeLastUpdated
    }
}

private enum WidgetConnectionStatus {
    case live
    case recent
    case stale
    case offline

    init(device: StromerWidgetDeviceSnapshot, now: Date) {
        self = Self.status(lastUpdated: device.lastUpdated, now: now)
    }

    static func aggregate(
        devices: [StromerWidgetDeviceSnapshot],
        now: Date
    ) -> WidgetConnectionStatus {
        guard !devices.isEmpty else {
            return .live
        }

        if devices.contains(where: { status(lastUpdated: $0.lastUpdated, now: now) == .offline }) {
            return .offline
        }
        if devices.contains(where: { status(lastUpdated: $0.lastUpdated, now: now) == .stale }) {
            return .stale
        }
        if devices.contains(where: { status(lastUpdated: $0.lastUpdated, now: now) == .recent }) {
            return .recent
        }
        return .live
    }

    var dimsValues: Bool {
        self == .stale || self == .offline
    }

    var indicatorColor: Color {
        switch self {
        case .live:
            return .boltOk
        case .recent:
            return .boltInkSoft
        case .stale:
            return .boltWarn
        case .offline:
            return .boltBad
        }
    }

    private static func status(lastUpdated: Date?, now: Date) -> WidgetConnectionStatus {
        guard let lastUpdated else {
            return .offline
        }

        let age = max(0, now.timeIntervalSince(lastUpdated))
        switch age {
        case 0..<120:
            return .live
        case 120..<1_800:
            return .recent
        case 1_800..<21_600:
            return .stale
        default:
            return .offline
        }
    }
}

private struct WidgetConnectionBackground: View {
    let status: WidgetConnectionStatus

    var body: some View {
        ZStack {
            BoltWidgetBackground()
            tint
        }
    }

    @ViewBuilder
    private var tint: some View {
        switch status {
        case .live:
            Color.clear
        case .recent:
            Color.boltInk.opacity(0.04)
        case .stale:
            Color.boltWarn.opacity(0.14)
        case .offline:
            Color.boltInk.opacity(0.12)
        }
    }
}

private struct MediumHeroWidget: View {
    let devices: [StromerWidgetDeviceSnapshot]
    let connectionStatus: WidgetConnectionStatus
    let lastUpdatedText: String

    private var aggregate: AggregateValue {
        let percentages = devices
            .filter { $0.mainUnit == "%" }
            .compactMap(\.numericMainValue)

        if !percentages.isEmpty {
            let average = percentages.reduce(0, +) / Double(percentages.count)
            return AggregateValue(
                value: average.formatted(.number.precision(.fractionLength(0))),
                unit: "%",
                label: "Gesamtladung",
                marker: min(max(average / 100, 0), 1)
            )
        }

        if let first = devices.first {
            return AggregateValue(
                value: first.mainValue,
                unit: first.mainUnit,
                label: first.mainLabel,
                marker: nil
            )
        }

        return AggregateValue(value: "--", unit: "", label: "Stromer", marker: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                BoltWidgetSLockup(size: 18)
                Text("Stromer".uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3.0)
                    .foregroundStyle(Color.boltInk)

                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(aggregate.value)
                    .font(.system(size: 48, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(aggregate.unit)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.boltTeal)
            }
            .foregroundStyle(Color.boltInk)
            .opacity(connectionStatus.dimsValues ? 0.62 : 1)

            Text(aggregate.label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(Color.boltInkSoft)

            WidgetHorizonLine(marker: aggregate.marker)
                .frame(height: 14)

            HStack(alignment: .top, spacing: 10) {
                ForEach(devices.prefix(3)) { device in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name.uppercased())
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(0.7)
                            .foregroundStyle(Color.boltInkSoft)
                            .lineLimit(1)
                        Text("\(device.mainValue) \(device.mainUnit)")
                            .font(.system(size: 13, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color.boltInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .opacity(device.isDimmed ? 0.55 : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 5) {
                Rectangle()
                    .fill(connectionStatus.indicatorColor)
                    .frame(width: 6, height: 6)
                Text("ÄLTESTER WERT · \(lastUpdatedText.uppercased())")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.boltInkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private struct AggregateValue {
        let value: String
        let unit: String
        let label: String
        let marker: Double?
    }
}

private struct DeviceWidgetTile: View {
    let device: StromerWidgetDeviceSnapshot
    let connectionStatus: WidgetConnectionStatus

    private var isSolar: Bool {
        device.boltKind == .solar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Spacer(minLength: 0)

            valueBlock
                .opacity(connectionStatus.dimsValues ? 0.55 : 1)

            if isSolar {
                BoltWidgetSpark(values: sparkValues, color: .boltYellow)
                    .frame(height: 15)
            } else {
                WidgetHorizonLine(marker: marker)
                    .frame(height: 14)
            }

            HStack(spacing: 5) {
                Rectangle()
                    .fill(connectionStatus.indicatorColor)
                    .frame(width: 6, height: 6)
                Text(device.relativeLastUpdated.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.boltInkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            if isSolar {
                Text("Solar".uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.boltTealDeep)
            } else {
                BoltWidgetSLockup(size: 15)
                Text(device.boltKind.shortLabel.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.boltInkSoft)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(device.mainValue)
                    .font(.system(size: 42, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(device.mainUnit)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.boltTeal)
            }

            Text(labelTitle)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Color.boltInkSoft)
                .lineLimit(1)
        }
        .foregroundStyle(Color.boltInk)
    }

    private var labelTitle: String {
        switch device.boltKind {
        case .battery:
            return "LADESTAND"
        case .solar:
            return "WATT JETZT"
        case .dcDc:
            return device.mainLabel.uppercased().contains("EINGANG") ? "EINGANG" : "AUSGANG"
        case .other:
            return device.mainLabel.uppercased()
        }
    }

    private var marker: Double? {
        guard device.mainUnit == "%", let value = device.numericMainValue else {
            return nil
        }

        return min(max(value / 100, 0), 1)
    }

    private var sparkValues: [Double] {
        guard let value = device.numericMainValue else {
            return []
        }

        return [value * 0.72, value * 0.84, value * 0.78, value * 0.93, value]
    }
}

private struct WidgetHorizonLine: View {
    let marker: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.boltInk)
                    .frame(height: 2)

                if let marker {
                    BoltWidgetGlyph(size: 10)
                        .position(
                            x: max(6, min(geometry.size.width - 6, geometry.size.width * marker)),
                            y: geometry.size.height / 2
                        )
                }
            }
        }
    }
}

private struct WidgetEmptyStateView: View {
    let status: StromerWidgetSnapshotStatus
    let compact: Bool

    private var content: WidgetEmptyStateContent {
        WidgetEmptyStateContent(status: status)
    }

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: compact ? 4 : 9) {
            if compact {
                Image(systemName: content.iconSystemName)
                    .font(.caption.weight(.bold))
            } else {
                BoltWidgetSLockup(size: 24)
            }

            Text("Stromer".uppercased())
                .font(.system(size: compact ? 8 : 9, weight: .heavy))
                .tracking(compact ? 1.2 : 2.4)
                .foregroundStyle(Color.boltInkSoft)

            Text(content.title.uppercased())
                .font(.system(size: compact ? 11 : 12, weight: .heavy))
                .tracking(compact ? 0.6 : 1.2)
                .foregroundStyle(Color.boltTeal)
                .lineLimit(compact ? 2 : 3)
                .multilineTextAlignment(compact ? .leading : .center)

            if !compact {
                Text(content.description)
                    .font(.caption2)
                    .foregroundStyle(Color.boltInkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .leading : .center)
    }
}

private struct WidgetEmptyStateContent {
    let iconSystemName: String
    let title: String
    let description: String

    init(status: StromerWidgetSnapshotStatus) {
        switch status {
        case .ready, .noDevices:
            iconSystemName = "plus.circle"
            title = "+ Gerät hinzufügen"
            description = "Öffne Stromer und registriere ein Victron-Gerät."
        case .deviceMissing:
            iconSystemName = "questionmark.circle"
            title = "Gerät nicht gefunden"
            description = "Wähle in der Widget-Konfiguration ein anderes Gerät."
        }
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
