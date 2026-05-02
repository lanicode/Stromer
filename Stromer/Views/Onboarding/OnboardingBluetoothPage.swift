import CoreBluetooth
import SwiftUI

struct OnboardingBluetoothPage: View {
    @StateObject private var permissionProbe = BluetoothPermissionProbe()

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingPageView(
            pageIndex: 2,
            eyebrow: "Bluetooth",
            title: "Bluetooth wird\ngebraucht.",
            bodyText: "Stromer scannt nach Victron-Advertisements in deiner Nähe. Es wird keine Verbindung aufgebaut und nichts an Geräte geschrieben.",
            primaryButtonTitle: primaryButtonTitle,
            primaryShowsBolt: !permissionProbe.canContinue,
            primaryAction: primaryAction,
            secondaryButtonTitle: "Überspringen",
            secondaryAction: onSkip,
            hero: {
                OnboardingAntennaHero()
            },
            content: {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusTitle)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(statusColor)

                        Spacer()
                    }

                    Text(statusDescription)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.boltInkSoft)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.boltPaper)
                .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
            }
        )
        .onAppear {
            permissionProbe.refresh()
        }
    }

    private var primaryButtonTitle: String {
        permissionProbe.canContinue ? "Weiter" : "Bluetooth aktivieren"
    }

    private func primaryAction() {
        if permissionProbe.canContinue {
            onContinue()
        } else {
            permissionProbe.requestPermission()
        }
    }

    private var statusTitle: String {
        switch permissionProbe.authorization {
        case .allowed:
            return "Bluetooth ist erlaubt"
        case .denied:
            return "Bluetooth-Zugriff abgelehnt"
        case .restricted:
            return "Bluetooth ist eingeschränkt"
        case .notDetermined:
            return "Bluetooth wurde noch nicht abgefragt"
        case .unknown:
            return "Bluetooth-Status unbekannt"
        }
    }

    private var statusDescription: String {
        if permissionProbe.centralState == .unsupported {
            return "Dieses Gerät unterstützt Bluetooth Low Energy nicht. Du kannst Stromer trotzdem weiter einrichten."
        }

        switch permissionProbe.authorization {
        case .allowed:
            return "Stromer kann nach Victron-Geräten in deiner Nähe suchen."
        case .denied:
            return "Du kannst das Onboarding fortsetzen. Discovery funktioniert später erst nach Freigabe in den iOS-Einstellungen."
        case .restricted:
            return "Du kannst das Onboarding fortsetzen. Bluetooth ist auf diesem Gerät aktuell eingeschränkt."
        case .notDetermined:
            return "Tippe auf „Bluetooth aktivieren“, damit iOS die Berechtigung abfragt."
        case .unknown:
            return "Du kannst fortfahren und den Bluetooth-Status später in den Einstellungen prüfen."
        }
    }

    private var statusColor: Color {
        if permissionProbe.centralState == .unsupported {
            return .boltBad
        }

        switch permissionProbe.authorization {
        case .allowed:
            return .boltTeal
        case .denied, .restricted:
            return .boltWarn
        case .notDetermined:
            return .boltYellowDeep
        case .unknown:
            return .boltInkSoft
        }
    }
}

private final class BluetoothPermissionProbe: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var authorization: BluetoothAuthorizationStatus = .current
    @Published private(set) var centralState: CBManagerState = .unknown

    private var central: CBCentralManager?

    var canContinue: Bool {
        switch authorization {
        case .allowed, .denied, .restricted, .unknown:
            return true
        case .notDetermined:
            return centralState == .unsupported
        }
    }

    func refresh() {
        authorization = .current
    }

    func requestPermission() {
        authorization = .current
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState = central.state
        authorization = .current
    }
}
