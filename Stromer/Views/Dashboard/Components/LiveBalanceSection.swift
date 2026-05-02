import SwiftUI

struct LiveBalanceSection: View {
    let solarIn: Double?
    let loadOut: Double?
    let net: Double?

    var body: some View {
        BoltSection(header: "Aktuell") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    balanceColumn(
                        label: "Solar rein",
                        value: solarIn,
                        unit: "W",
                        color: .boltYellow
                    )

                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(width: 1)

                    balanceColumn(
                        label: "Verbrauch raus",
                        value: loadOut,
                        unit: "W",
                        color: .boltInk
                    )
                }

                Rectangle()
                    .fill(Color.boltHair)
                    .frame(height: 1)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    BoltEyebrow("Netto")

                    Spacer()

                    Text(format(net))
                        .font(.system(size: 34, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(netColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("W")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.boltInkSoft)
                }
            }
            .padding(16)
        }
    }

    private func balanceColumn(label: String, value: Double?, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.boltMono(11))
                .tracking(0.8)
                .foregroundStyle(Color.boltInkSoft)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format(value))
                    .font(.system(size: 30, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.boltInkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var netColor: Color {
        guard let net else {
            return .boltInkSoft
        }
        return net >= 0 ? .boltTeal : .boltWarn
    }

    private func format(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
    }
}
