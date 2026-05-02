import SwiftUI

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let systemImage: String
    let text: String
}

struct OnboardingPageView<Content: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        primaryButtonTitle: String? = "Weiter",
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 26)

                    Image(systemName: systemImage)
                        .font(.system(size: 58, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .frame(width: 92, height: 92)
                        .background(.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)

                        if let subtitle {
                            Text(subtitle)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    content

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 11) {
                if let primaryButtonTitle, let primaryAction {
                    Button(primaryButtonTitle, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }

                if let secondaryButtonTitle, let secondaryAction {
                    Button(secondaryButtonTitle, action: secondaryAction)
                        .buttonStyle(.borderless)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 42)
            .background(.background)
        }
    }
}

struct OnboardingFeatureList: View {
    let features: [OnboardingFeature]
    let checkmarkStyle: Bool

    init(features: [OnboardingFeature], checkmarkStyle: Bool = false) {
        self.features = features
        self.checkmarkStyle = checkmarkStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: checkmarkStyle ? "checkmark.circle.fill" : feature.systemImage)
                        .font(.title3)
                        .foregroundStyle(checkmarkStyle ? Color.green : Color.accentColor)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    Text(feature.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
