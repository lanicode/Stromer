import Charts
import SwiftUI

struct ComparisonSection: View {
    let weekComparison: ComparisonStats?
    let monthComparison: ComparisonStats?

    var body: some View {
        BoltSection(header: "Vergleiche") {
            VStack(spacing: 0) {
                comparisonRow(weekComparison, fallback: "Noch kein Wochenvergleich")
                Rectangle().fill(Color.boltHair2).frame(height: 1)
                comparisonRow(monthComparison, fallback: "Noch kein Zeitraumvergleich", isLast: true)
            }
        }
    }

    private func comparisonRow(
        _ stats: ComparisonStats?,
        fallback: String,
        isLast: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(color(for: stats?.percentChange))
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(45))

            VStack(alignment: .leading, spacing: 2) {
                Text(stats?.title ?? fallback)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.boltInk)

                Text(stats?.detail ?? "Stromer sammelt noch Vergleichsdaten.")
                    .font(.boltMono(11))
                    .foregroundStyle(Color.boltInkSoft)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func color(for percent: Double?) -> Color {
        guard let percent else {
            return .boltInkFaint
        }
        return percent >= 0 ? .boltTeal : .boltWarn
    }
}

struct HistoryInlineEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            BoltEyebrow("Daten werden gesammelt")
            Text(text)
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }
}

var historyDayAxis: some AxisContent {
    AxisMarks(values: .automatic(desiredCount: 5)) {
        AxisGridLine().foregroundStyle(Color.boltHair2)
        AxisTick().foregroundStyle(Color.boltHair)
        AxisValueLabel(format: .dateTime.day().month())
            .font(.boltMono(10))
            .foregroundStyle(Color.boltInkSoft)
    }
}

var historyValueAxis: some AxisContent {
    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(Color.boltHair2)
        AxisTick().foregroundStyle(Color.boltHair)
        AxisValueLabel()
            .font(.boltMono(10))
            .foregroundStyle(Color.boltInkSoft)
    }
}

var historyPercentAxis: some AxisContent {
    AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) {
        AxisGridLine().foregroundStyle(Color.boltHair2)
        AxisTick().foregroundStyle(Color.boltHair)
        AxisValueLabel()
            .font(.boltMono(10))
            .foregroundStyle(Color.boltInkSoft)
    }
}
