import StromerScanner
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("Bluetooth") {
                LabeledContent("Berechtigung") {
                    Text(appModel.bluetoothAuthorization.title)
                        .foregroundStyle(authorizationColor)
                }

                if appModel.bluetoothAuthorization.needsSettingsAction {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Einstellungen öffnen", systemImage: "gearshape")
                    }
                }

                LabeledContent("Scanner") {
                    Text(scannerStateTitle)
                        .foregroundStyle(scannerStateColor)
                }

                HStack {
                    Button {
                        Task {
                            await appModel.restartScanner()
                        }
                    } label: {
                        Label("Scanner neu starten", systemImage: "arrow.clockwise")
                    }

                    Spacer()

                    Button {
                        Task {
                            await appModel.stopScanner()
                        }
                    } label: {
                        Label("Stoppen", systemImage: "stop.circle")
                    }
                    .buttonStyle(.borderless)
                }

                Text("Im Hintergrund empfängt iOS Victron-Advertisements opportunistisch. Der Aktualitätsstatus zeigt deshalb, wie alt der letzte Wert ist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastErrorMessage = appModel.lastErrorMessage {
                Section("Hinweis") {
                    Label(lastErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                NavigationLink {
                    ContentUnavailableView(
                        "Open-Source-Lizenzen",
                        systemImage: "doc.text",
                        description: Text("Die Lizenzübersicht wird in einer späteren Phase ergänzt.")
                    )
                } label: {
                    Label("Open-Source-Lizenzen", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    dismiss()
                }
            }
        }
        .onAppear {
            appModel.refreshRuntimeState()
        }
    }

    private var scannerStateTitle: String {
        switch appModel.scannerState {
        case .idle:
            return "Bereit"
        case .scanning:
            return "Scannt"
        case .unauthorized:
            return "Keine Berechtigung"
        case .off:
            return "Bluetooth aus"
        case .unsupported:
            return "Nicht unterstützt"
        case .resetting:
            return "Wird zurückgesetzt"
        case .unknown:
            return "Unbekannt"
        case let .failed(message):
            return "Fehler: \(message)"
        }
    }

    private var scannerStateColor: Color {
        switch appModel.scannerState {
        case .scanning:
            return .green
        case .off, .unauthorized, .unsupported, .failed:
            return .red
        case .idle, .resetting, .unknown:
            return .secondary
        }
    }

    private var authorizationColor: Color {
        switch appModel.bluetoothAuthorization {
        case .allowed:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined, .unknown:
            return .secondary
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
