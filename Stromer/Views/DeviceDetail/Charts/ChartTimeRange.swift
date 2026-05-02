import SwiftUI

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Heute"
        case .sevenDays:
            return "7 Tage"
        case .thirtyDays:
            return "30 Tage"
        case .year:
            return "Jahr"
        }
    }

    func interval(endingAt now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .today:
            return DateInterval(start: calendar.startOfDay(for: now), end: now)
        case .sevenDays:
            return DateInterval(start: now.addingTimeInterval(-7 * 24 * 60 * 60), end: now)
        case .thirtyDays:
            return DateInterval(start: now.addingTimeInterval(-30 * 24 * 60 * 60), end: now)
        case .year:
            let start = calendar.date(byAdding: .day, value: -365, to: now) ?? now
            return DateInterval(start: start, end: now)
        }
    }

    var emptyDescription: String {
        switch self {
        case .year:
            return "Die Jahres-Übersicht ist verfügbar, sobald mehrere Wochen Daten gesammelt wurden."
        case .today, .sevenDays, .thirtyDays:
            return "Stromer sammelt Verlaufsdaten ab heute. Sobald Advertisements empfangen werden, erscheinen die Werte hier."
        }
    }
}

enum DeviceHistoryKind {
    case battery
    case solar
    case dcDc
}

struct DeviceHistorySection: View {
    let deviceID: UUID
    let kind: DeviceHistoryKind
    let historyStore: (any HistoryStore)?
    @State private var selectedRange: ChartTimeRange = .today

    var body: some View {
        BoltSection(header: "Verlauf") {
            VStack(spacing: 16) {
                ChartRangeSegmentedControl(selection: $selectedRange)

                chartView
                    .frame(minHeight: 250)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var chartView: some View {
        switch kind {
        case .battery:
            BatteryChartView(
                deviceID: deviceID,
                timeRange: selectedRange,
                historyStore: historyStore
            )
        case .solar:
            SolarChartView(
                deviceID: deviceID,
                timeRange: selectedRange,
                historyStore: historyStore
            )
        case .dcDc:
            DcDcChartView(
                deviceID: deviceID,
                timeRange: selectedRange,
                historyStore: historyStore
            )
        }
    }
}

private struct ChartRangeSegmentedControl: View {
    @Binding var selection: ChartTimeRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(selection == range ? Color.boltCream : Color.boltInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == range ? Color.boltInk : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.boltInk, lineWidth: 1))
    }
}

struct HistoryChartEmptyState: View {
    let timeRange: ChartTimeRange

    var body: some View {
        VStack(spacing: 10) {
            BoltEyebrow("Noch keine Daten")
            Text(timeRange.emptyDescription)
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct HistoryChartFootnote: View {
    let gapCount: Int

    var body: some View {
        if gapCount > 0 {
            Text("\(gapCount) Lücken im Zeitraum erkannt - iPhone war nicht in Reichweite.")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HistoryChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct HistoryRangePoint: Identifiable {
    let id = UUID()
    let date: Date
    let min: Double
    let max: Double
    let avg: Double?
}

struct HistoryLineSegment: Identifiable {
    let id = UUID()
    let points: [HistoryChartPoint]
}

enum HistoryChartDataMapper {
    static let liveGapThreshold: TimeInterval = 5 * 60

    static func downsample(_ points: [HistoryChartPoint], limit: Int = 5_000) -> [HistoryChartPoint] {
        guard points.count > limit else {
            return points
        }

        let stride = Int(ceil(Double(points.count) / Double(limit)))
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    static func lineSegments(
        points: [HistoryChartPoint],
        gapThreshold: TimeInterval = liveGapThreshold
    ) -> [HistoryLineSegment] {
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else {
            return []
        }

        var segments: [HistoryLineSegment] = []
        var current: [HistoryChartPoint] = []
        var previousDate: Date?

        for point in sorted {
            if let previousDate,
               point.date.timeIntervalSince(previousDate) > gapThreshold,
               !current.isEmpty {
                segments.append(HistoryLineSegment(points: current))
                current = []
            }

            current.append(point)
            previousDate = point.date
        }

        if !current.isEmpty {
            segments.append(HistoryLineSegment(points: current))
        }

        return segments
    }

    static func gapCount(in points: [HistoryChartPoint], threshold: TimeInterval = liveGapThreshold) -> Int {
        let sortedDates = points.map(\.date).sorted()
        guard sortedDates.count > 1 else {
            return 0
        }

        return zip(sortedDates, sortedDates.dropFirst()).reduce(0) { count, pair in
            pair.1.timeIntervalSince(pair.0) > threshold ? count + 1 : count
        }
    }
}
