import SwiftUI

struct InsightsSection: View {
    let insights: [DashboardInsight]

    var body: some View {
        BoltSection(header: "Insights") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.boltYellow)
                            .frame(width: 20)

                        Text(insight.text)
                            .font(.boltBody)
                            .foregroundStyle(Color.boltInk)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)

                    if index < insights.count - 1 {
                        Rectangle()
                            .fill(Color.boltHair2)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}
