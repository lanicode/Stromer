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
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
    }

    private var welcomePage: some View {
        OnboardingPageView(
            systemImage: "bolt.batteryblock",
            title: "Stromer",
            subtitle: "Live-Werte für deine Victron-Geräte. Direkt auf dem iPhone, ohne Cloud.",
            primaryButtonTitle: "Weiter",
            primaryAction: nextPage,
            secondaryButtonTitle: "Später einrichten",
            secondaryAction: { onComplete(.finish) }
        )
    }

    private var explanationPage: some View {
        OnboardingPageView(
            systemImage: "dot.radiowaves.left.and.right",
            title: "Was ist Stromer?",
            primaryButtonTitle: "Weiter",
            primaryAction: nextPage,
            content: {
                OnboardingFeatureList(features: [
                    OnboardingFeature(
                        systemImage: "antenna.radiowaves.left.and.right",
                        text: "Empfängt Victron Instant Readout per Bluetooth"
                    ),
                    OnboardingFeature(
                        systemImage: "battery.100",
                        text: "Zeigt SmartShunt/BMV und MPPT-Livewerte direkt an"
                    ),
                    OnboardingFeature(
                        systemImage: "clock.arrow.circlepath",
                        text: "Weitere Familien wie Orion Smart folgen"
                    ),
                    OnboardingFeature(
                        systemImage: "icloud.slash",
                        text: "Kein Cerbo GX und keine Cloud nötig"
                    )
                ])
            }
        )
    }

    private var privacyPage: some View {
        OnboardingPageView(
            systemImage: "lock.shield",
            title: "Privat by Design",
            primaryButtonTitle: "Weiter",
            primaryAction: nextPage,
            content: {
                OnboardingFeatureList(
                    features: [
                        OnboardingFeature(
                            systemImage: "checkmark.circle.fill",
                            text: "Passive Victron-BLE-Advertisements"
                        ),
                        OnboardingFeature(
                            systemImage: "checkmark.circle.fill",
                            text: "Messwerte bleiben lokal auf deinem iPhone"
                        ),
                        OnboardingFeature(
                            systemImage: "checkmark.circle.fill",
                            text: "Advertisement Keys liegen im iOS-Schlüsselbund"
                        ),
                        OnboardingFeature(
                            systemImage: "checkmark.circle.fill",
                            text: "Keine Cloud, kein Tracking, keine Analytics"
                        ),
                        OnboardingFeature(
                            systemImage: "checkmark.circle.fill",
                            text: "Discovery zeigt fremde Victron-Geräte nur als Modell/Typ, Messwerte bleiben verschlüsselt"
                        )
                    ],
                    checkmarkStyle: true
                )
            }
        )
    }

    private var firstDevicePage: some View {
        OnboardingPageView(
            systemImage: "plus.circle",
            title: "Erstes Gerät hinzufügen",
            subtitle: "Wir suchen jetzt nach Victron-Geräten in deiner Nähe. Du kannst dein Gerät auch später manuell hinzufügen.",
            primaryButtonTitle: "Gerät suchen",
            primaryAction: { onComplete(.addDevice) },
            secondaryButtonTitle: "Onboarding abschließen",
            secondaryAction: { onComplete(.finish) }
        )
    }

    private func nextPage() {
        selectedPage = min(selectedPage + 1, 5)
    }

    private func skipBluetooth() {
        selectedPage = 3
    }
}
