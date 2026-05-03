import Charts
import SwiftUI

struct SolarHistorySection: View {
    let timeRange: HistoryOverviewRange
    let points: [DailyYieldPoint]
    let totalKwh: Double
    let bestDay: DailyYieldPoint?

    var body: some View {
        BoltSection(header: "Solar-Ertrag") {
            VStack(alignment: .leading, spacing: 12) {
                if points.isEmpty {
                    HistoryInlineEmptyState(text: "Noch keine Solar-Tageswerte im gewählten Zeitraum.")
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("Tag", point.date),
                                y: .value("Wh", point.yieldWh)
                            )
                            .foregroundStyle(point.id == bestDay?.id ? Color.boltYellowDeep : Color.boltYellow)
                        }
                    }
                    .chartXAxis { stromerDateAxis(for: timeRange.axisRange) }
                    .chartYAxis { historyValueAxis }
                    .frame(height: 170)

                    HStack {
                        metric("Total", "\(DevicePresentation.number(totalKwh, digits: 2)) kWh")
                        Spacer()
                        if let bestDay {
                            metric("Bester Tag", "\(dayLabel(bestDay.date)) · \(DevicePresentation.number(bestDay.yieldWh, digits: 0)) Wh")
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            BoltEyebrow(label)
            Text(value)
                .font(.boltMono(12))
                .fontWeight(.bold)
                .foregroundStyle(Color.boltInk)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date)
    }
}
