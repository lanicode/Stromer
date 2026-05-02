import SwiftUI

enum OnboardingCompletionAction {
    case finish
    case addDevice
}

struct OnboardingFlowView: View {
    let onComplete: (OnboardingCompletionAction) -> Void

    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            welcomePage
                .tag(0)
            explanationPage
                .tag(1)
            OnboardingBluetoothPage(
                onContinue: nextPage,
                onSkip: skipBluetooth
            )
            .tag(2)
            privacyPage
                .tag(3)
            OnboardingKeyGuideView(onContinue: nextPage)
                .tag(4)
            firstDevicePage
                .tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(BoltBackground())
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
    }

    private var welcomePage: some View {
        OnboardingPageView(
            pageIndex: 0,
            eyebrow: "STROMER · IOS",
            title: "Live-Werte\nohne Cloud.",
            bodyText: "Victron Instant Readout direkt am iPhone. Kein Cerbo, kein Account, kein Tracking.",
            primaryButtonTitle: "Loslegen",
            primaryShowsBolt: true,
            primaryAction: nextPage,
            secondaryButtonTitle: "Später einrichten",
            secondaryAction: { onComplete(.finish) },
            hero: {
                OnboardingWelcomeHero()
            }
        )
    }

    private var explanationPage: some View {
        OnboardingPageView(
            pageIndex: 1,
            eyebrow: "Was ist Stromer",
            title: "Drei Sätze.",
            primaryButtonTitle: "Weiter",
            primaryAction: nextPage,
            hero: {
                OnboardingBandsHero()
            },
            content: {
                OnboardingBulletList(bullets: [
                    OnboardingBullet(
                        key: "BLE",
                        text: "Empfängt Victron Advertisements passiv per Bluetooth."
                    ),
                    OnboardingBullet(
                        key: "LIVE",
                        text: "SmartShunt, BMV und MPPT in Echtzeit."
                    ),
                    OnboardingBullet(
                        key: "LOKAL",
                        text: "Keine Cloud. Keine Synchronisierung. Keine Analytics."
                    )
                ])
            }
        )
    }

    private var privacyPage: some View {
        OnboardingPageView(
            pageIndex: 3,
            eyebrow: "Privatsphäre",
            title: "Privat by\nDesign.",
            primaryButtonTitle: "Weiter",
            primaryAction: nextPage,
            hero: {
                OnboardingShieldHero()
            },
            content: {
                OnboardingBulletList(bullets: [
                    OnboardingBullet(
                        key: "01",
                        text: "Passive BLE-Advertisements - Stromer schreibt nie an Geräte."
                    ),
                    OnboardingBullet(
                        key: "02",
                        text: "Messwerte bleiben auf diesem iPhone."
                    ),
                    OnboardingBullet(
                        key: "03",
                        text: "Advertisement Keys liegen im Schlüsselbund."
                    ),
                    OnboardingBullet(
                        key: "04",
                        text: "Kein Tracking. Keine Analytics. Kein Account."
                    )
                ])
            }
        )
    }

    private var firstDevicePage: some View {
        OnboardingPageView(
            pageIndex: 5,
            eyebrow: "Erstes Gerät",
            title: "Jetzt geht's\nlos.",
            bodyText: "Wir suchen jetzt nach Victron-Geräten in deiner Nähe. Du kannst dein Gerät auch später manuell hinzufügen.",
            primaryButtonTitle: "Gerät suchen",
            primaryShowsBolt: true,
            primaryAction: { onComplete(.addDevice) },
            secondaryButtonTitle: "Onboarding abschließen",
            secondaryAction: { onComplete(.finish) },
            hero: {
                OnboardingAddHero()
            }
        )
    }

    private func nextPage() {
        selectedPage = min(selectedPage + 1, 5)
    }

    private func skipBluetooth() {
        selectedPage = 3
    }
}
