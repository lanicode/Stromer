import SwiftUI

struct PipLiveDashboard: View {
    let elapsedSeconds: Int
    let readsTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("PiP")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(formattedElapsed)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.82))
            }

            Text("Reads: \(readsTotal)")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.06, blue: 0.08),
                    Color(red: 0.02, green: 0.12, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var formattedElapsed: String {
        let clampedSeconds = max(0, elapsedSeconds)
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
