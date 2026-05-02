import Charts
import SwiftUI

struct TrendChartSection: View {
    let points: [DailyYieldPoint]
    let bestDayLabel: String?
    let bestDayYield: Double?

    var body: some View {
        BoltSection(header: "Letzte 7 Tage") {
            VStack(alignment: .leading, spacing: 12) {
                if points.isEmpty {
                    VStack(spacing: 8) {
                        BoltEyebrow("Daten werden gesammelt")
                        Text("Sobald Tageswerte vorliegen, zeigt Stromer hier den Solartrend der letzten Woche.")
                            .font(.boltBody)
                            .foregroundStyle(Color.boltInkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("Tag", point.date),
                                y: .value("Ertrag", point.yieldWh)
                            )
                            .foregroundStyle(isBest(point) ? Color.boltYellowDeep : Color.boltYellow)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine().foregroundStyle(Color.boltHair2)
                            AxisTick().foregroundStyle(Color.boltHair)
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.boltMono(10))
                                .foregroundStyle(Color.boltInkSoft)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(Color.boltHair2)
                            AxisTick().foregroundStyle(Color.boltHair)
                            AxisValueLabel()
                                .font(.boltMono(10))
                                .foregroundStyle(Color.boltInkSoft)
                        }
                    }
                    .frame(height: 120)

                    if let bestDayLabel, let bestDayYield {
                        Text("Bester Tag: \(bestDayLabel) (\(DevicePresentation.number(bestDayYield, digits: 0)) Wh)")
                            .font(.system(size: 11).italic())
                            .foregroundStyle(Color.boltInkSoft)
                    }
                }
            }
            .padding(16)
        }
    }

    private func isBest(_ point: DailyYieldPoint) -> Bool {
        guard let bestDayYield else {
            return false
        }
        return point.yieldWh == bestDayYield
    }
}
