import Charts
import SwiftUI

struct BatteryHistorySection: View {
    let ranges: [SocRangePoint]
    let lowestDay: SocRangePoint?
    let fullCharges: Int

    var body: some View {
        BoltSection(header: "Batterie-Verlauf") {
            VStack(alignment: .leading, spacing: 12) {
                if ranges.isEmpty {
                    HistoryInlineEmptyState(text: "Noch keine Batterie-Tageswerte im gewählten Zeitraum.")
                } else {
                    Chart {
                        ForEach(ranges) { point in
                            AreaMark(
                                x: .value("Tag", point.date),
                                yStart: .value("Min", point.min),
                                yEnd: .value("Max", point.max)
                            )
                            .foregroundStyle(Color.boltTealSoft)

                            if let avg = point.avg {
                                LineMark(
                                    x: .value("Tag", point.date),
                                    y: .value("SoC", avg)
                                )
                                .foregroundStyle(Color.boltTeal)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis { historyDayAxis }
                    .chartYAxis { historyPercentAxis }
                    .frame(height: 170)

                    HStack {
                        metric("Volladungen", "\(fullCharges)")
                        Spacer()
                        if let lowestDay {
                            metric("Niedrigster Tag", "\(dayLabel(lowestDay.date)) · \(Int(lowestDay.min.rounded()))%")
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
