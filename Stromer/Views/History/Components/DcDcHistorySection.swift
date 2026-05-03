import Charts
import SwiftUI

struct DcDcHistorySection: View {
    let timeRange: HistoryOverviewRange
    let points: [DailyChargingPoint]
    let totalChargingHours: Double

    var body: some View {
        BoltSection(header: "DC/DC Ladezeiten") {
            VStack(alignment: .leading, spacing: 12) {
                if points.isEmpty {
                    HistoryInlineEmptyState(text: "Noch keine Orion-Ladezeiten im gewählten Zeitraum.")
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("Tag", point.date),
                                y: .value("Minuten", point.minutes)
                            )
                            .foregroundStyle(Color.boltTeal)
                        }
                    }
                    .chartXAxis { stromerDateAxis(for: timeRange.axisRange) }
                    .chartYAxis { historyValueAxis }
                    .frame(height: 150)

                    Text("Total Ladezeit: \(DevicePresentation.number(totalChargingHours, digits: 1)) Stunden")
                        .font(.boltMono(12))
                        .foregroundStyle(Color.boltInkSoft)
                }
            }
            .padding(16)
        }
    }
}
