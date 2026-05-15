import SwiftUI

struct PipLiveDashboard: View {
    let primaryValue: String
    let primaryUnit: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let relativeUpdatedText: String
    let isStale: Bool
    let elapsedSeconds: Int
    let readsTotal: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundGradient

            VStack(alignment: .leading, spacing: 0) {
                valueStack
                    .opacity(isStale ? 0.45 : 1)

                Spacer(minLength: 4)

                Text("PiP \(formattedElapsed) · Reads \(readsTotal)")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.boltInkFaint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(8)

            if isStale {
                Rectangle()
                    .fill(Color.boltWarn)
                    .frame(width: 12, height: 3)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .colorScheme(.light)
    }

    private var valueStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(primaryValue)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.boltInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Text(primaryUnit)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.boltTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            Text(primaryLabel)
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.boltInkSoft)
                .lineLimit(1)

            if hasSecondaryValues {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(secondaryValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.boltInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text("· \(secondaryLabel)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.boltInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.top, 8)
            }

            Text(relativeUpdatedText)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.boltInkSoft)
                .lineLimit(1)
                .padding(.top, 2)
        }
    }

    private var hasSecondaryValues: Bool {
        secondaryValue != "—" || secondaryLabel != "—"
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.boltCream,
                Color.boltCreamDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var formattedElapsed: String {
        let clampedSeconds = max(0, elapsedSeconds)
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
