import SwiftUI

struct OnboardingKeyGuideView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingPageView(
            systemImage: "key",
            title: "Advertisement Key finden",
            primaryButtonTitle: "Weiter",
            primaryAction: onContinue,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.number)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(.tint, in: Circle())
                                .accessibilityHidden(true)

                            Image(systemName: step.systemImage)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                                .accessibilityHidden(true)

                            Text(step.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
        )
    }

    private var steps: [KeyGuideStep] {
        [
            KeyGuideStep(number: 1, systemImage: "iphone", title: "VictronConnect öffnen"),
            KeyGuideStep(number: 2, systemImage: "hand.tap", title: "Gerät auswählen"),
            KeyGuideStep(number: 3, systemImage: "gearshape", title: "Zahnrad öffnen"),
            KeyGuideStep(number: 4, systemImage: "doc.text", title: "Product Info öffnen"),
            KeyGuideStep(number: 5, systemImage: "eye", title: "Instant Readout Details anzeigen"),
            KeyGuideStep(number: 6, systemImage: "doc.on.clipboard", title: "32-stelligen Key kopieren")
        ]
    }
}

private struct KeyGuideStep: Identifiable {
    let number: Int
    let systemImage: String
    let title: String

    var id: Int { number }
}
