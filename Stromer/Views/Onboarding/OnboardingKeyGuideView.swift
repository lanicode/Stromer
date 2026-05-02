import SwiftUI

struct OnboardingKeyGuideView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingPageView(
            pageIndex: 4,
            eyebrow: "Advertisement Key",
            title: "Key in\nVictronConnect\nfinden.",
            primaryButtonTitle: "Weiter",
            primaryAction: onContinue,
            hero: {
                OnboardingKeyHero()
            },
            content: {
                OnboardingBulletList(bullets: steps)
            }
        )
    }

    private var steps: [OnboardingBullet] {
        [
            OnboardingBullet(key: "01", text: "VictronConnect öffnen"),
            OnboardingBullet(key: "02", text: "Gerät auswählen"),
            OnboardingBullet(key: "03", text: "Geräteeinstellungen öffnen"),
            OnboardingBullet(key: "04", text: "Product Info öffnen"),
            OnboardingBullet(key: "05", text: "Instant Readout Details anzeigen"),
            OnboardingBullet(key: "06", text: "32-stelligen Key kopieren")
        ]
    }
}
