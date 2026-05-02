import SwiftUI

struct TodayStatsSection: View {
    let solarYield: Double?
    let consumption: Double?
    let socMin: Double?
    let socMax: Double?
    let fullCharges: Int?

    var body: some View {
        BoltSection(header: "Heute") {
            VStack(spacing: 0) {
                statRow("Solar-Ertrag", value: whText(solarYield))
                statRow("Verbrauch", value: whText(consumption))
                statRow("SoC-Spanne", value: socRangeText, isLast: false)
                statRow("Volladungen", value: fullCharges.map(String.init) ?? "--", isLast: true)
            }
        }
    }

    private var socRangeText: String {
        guard let socMin, let socMax else {
            return "--"
        }
        return "\(Int(socMin.rounded())) - \(Int(socMax.rounded())) %"
    }

    private func whText(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        if value >= 1_000 {
            return "\(DevicePresentation.number(value / 1_000, digits: 2)) kWh"
        }
        return "\(DevicePresentation.number(value, digits: 0)) Wh"
    }

    private func statRow(_ title: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.boltInk)

                Spacer()

                Text(value)
                    .font(.boltMono(13))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.boltInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if !isLast {
                Rectangle()
                    .fill(Color.boltHair2)
                    .frame(height: 1)
            }
        }
    }
}
