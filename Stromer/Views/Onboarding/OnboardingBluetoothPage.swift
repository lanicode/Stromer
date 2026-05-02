import CoreBluetooth
import SwiftUI

struct OnboardingBluetoothPage: View {
    @StateObject private var permissionProbe = BluetoothPermissionProbe()

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingPageView(
            systemImage: "bluetooth",
            title: "Bluetooth wird gebraucht",
            subtitle: "Stromer scannt nach Victron-Advertisements in deiner Nähe. Es wird keine Verbindung aufgebaut und nichts an Geräte geschrieben.",
            primaryButtonTitle: primaryButtonTitle,
            primaryAction: primaryAction,
            secondaryButtonTitle: "Überspringen",
            secondaryAction: onSkip,
            content: {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(statusTitle)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
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
            return .red
        }

        switch permissionProbe.authorization {
        case .allowed:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        case .unknown:
            return .secondary
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
