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
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.46))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)

            if isStale {
                Rectangle()
                    .fill(Color(red: 1, green: 0.58, blue: 0.17))
                    .frame(width: 18, height: 5)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var valueStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(primaryValue)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Text(primaryUnit)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            Text(primaryLabel)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(secondaryValue)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text("· \(secondaryLabel)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, 8)

            Text(relativeUpdatedText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.48))
                .lineLimit(1)
                .padding(.top, 2)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.06, blue: 0.08),
                Color(red: 0.02, green: 0.12, blue: 0.15)
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
