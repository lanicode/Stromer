import StromerScanner
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isShowingAddDevice = false
    @State private var isShowingLicenses = false

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        scannerStatusBlock
                            .padding(.horizontal, 18)

                        bluetoothSection
                            .padding(.horizontal, 18)

                        notificationsSection
                            .padding(.horizontal, 18)

                        if let lastErrorMessage = appModel.lastErrorMessage {
                            errorSection(lastErrorMessage)
                                .padding(.horizontal, 18)
                        }

                        devicesSection
                            .padding(.horizontal, 18)

                        privacySection
                            .padding(.horizontal, 18)

                        appSection
                            .padding(.horizontal, 18)

                        footer
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            appModel.refreshRuntimeState()
        }
        .sheet(isPresented: $isShowingAddDevice) {
            NavigationStack {
                AddDeviceView()
            }
        }
        .sheet(isPresented: $isShowingLicenses) {
            NavigationStack {
                ContentUnavailableView(
                    "Open-Source-Lizenzen",
                    systemImage: "doc.text",
                    description: Text("Die Lizenzübersicht wird in einer späteren Phase ergänzt.")
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            isShowingLicenses = false
                        }
                    }
                }
            }
        }
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 44)

            HStack(spacing: 8) {
                BoltSLockup(size: 20)
                Text("Einstellungen".uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.boltInk)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Fertig".uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.boltTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var scannerStatusBlock: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(isScannerActive ? Color.boltTeal : Color.boltHair)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isScannerActive ? Color.boltCream : Color.boltInkSoft)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                BoltEyebrow("Bluetooth Scanner")
                Text(isScannerActive ? "Aktiv · sucht Advertisements" : "Pausiert")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.boltInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            SettingsScannerSwitch(isOn: isScannerActive) {
                Task {
                    await toggleScanner()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        .boltCornerNotch(size: 22)
    }

    private var bluetoothSection: some View {
        BoltSection(
            header: "Bluetooth",
            footer: "Im Hintergrund empfängt iOS Victron-Advertisements opportunistisch. Stromer zeigt deshalb immer den letzten bekannten Wert mit Aktualitätsstatus."
        ) {
            SettingsRow(title: "Berechtigung") {
                StatusPill(
                    title: authorizationTitle,
                    color: authorizationColor,
                    symbol: authorizationSymbol
                )
            }

            if appModel.bluetoothAuthorization.needsSettingsAction {
                SettingsRow(
                    title: "Einstellungen öffnen",
                    iconSystemName: "gearshape",
                    tint: .boltTeal
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } trailing: {
                    Image(systemName: "arrow.up.forward")
                }
            }

            SettingsRow(title: "Scanner") {
                Text(scannerStateTitle.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(scannerStateColor)
            }

            SettingsRow(
                title: isScannerActive ? "Scanner stoppen" : "Scanner neu starten",
                iconSystemName: isScannerActive ? "stop.fill" : "arrow.clockwise",
                tint: .boltTeal,
                isLast: true
            ) {
                Task {
                    await toggleScanner()
                }
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
        }
    }

    private var notificationsSection: some View {
        BoltSection(
            header: "Benachrichtigungen",
            footer: "Lokale Hinweise, ohne Server-Push und ohne Tracking."
        ) {
            NavigationLink {
                NotificationSettingsView(
                    settings: appModel.notificationSettings,
                    sunsetService: appModel.sunsetService,
                    scheduler: appModel.dailyInsightScheduler,
                    notificationCoordinator: appModel.notificationCoordinator,
                    devices: appModel.registeredDevices
                )
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.boltTeal)
                            .frame(width: 20)

                        Text("Smart Notifications")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.boltInk)

                        Spacer(minLength: 12)

                        StatusPill(
                            title: appModel.notificationSettings.notificationsEnabled ? "Aktiv" : "Aus",
                            color: appModel.notificationSettings.notificationsEnabled ? .boltTealDeep : .boltInkSoft,
                            symbol: appModel.notificationSettings.notificationsEnabled ? "diamond.fill" : "pause.fill"
                        )

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func errorSection(_ message: String) -> some View {
        BoltSection(header: "Hinweis") {
            SettingsRow(
                title: message,
                iconSystemName: "exclamationmark.triangle.fill",
                tint: .boltWarn,
                isLast: true
            ) {
            } trailing: {
                EmptyView()
            }
        }
    }

    private var devicesSection: some View {
        BoltSection(header: "Geräte") {
            if appModel.registeredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Noch nichts eingerichtet")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.boltInk)
                    Text("Bluetooth-Status und Scanner-Steuerung sind bereit. Füge ein Gerät hinzu, um Live-Werte zu sehen.")
                        .font(.boltBody)
                        .foregroundStyle(Color.boltInkSoft)
                    BoltPrimary("Gerät hinzufügen", showsBolt: true) {
                        isShowingAddDevice = true
                    }
                }
                .padding(16)
            } else {
                SettingsRow(title: "Registrierte Geräte", isLast: true) {
                    Text("\(appModel.registeredDevices.count)")
                        .font(.boltMono(13))
                        .foregroundStyle(Color.boltInkSoft)
                }
            }
        }
    }

    private var privacySection: some View {
        BoltSection(header: "Privatsphäre") {
            VStack(alignment: .leading, spacing: 0) {
                PrivacyItem(
                    title: "Passive BLE-Scans",
                    description: "Stromer schreibt nie an Geräte."
                )
                PrivacyItem(
                    title: "Lokale Speicherung",
                    description: "Messwerte bleiben auf diesem iPhone."
                )
                PrivacyItem(
                    title: "Schlüsselbund",
                    description: "Advertisement Keys werden im iOS Keychain abgelegt."
                )
                PrivacyItem(
                    title: "Keine Cloud · kein Tracking",
                    description: "Keine Analytics. Kein Account.",
                    isLast: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private var appSection: some View {
        BoltSection(header: "App") {
            SettingsRow(title: "Version") {
                Text(appVersion)
                    .font(.boltMono(12))
                    .foregroundStyle(Color.boltInkSoft)
            }

            SettingsRow(title: "Build") {
                Text(buildNumber)
                    .font(.boltMono(12))
                    .foregroundStyle(Color.boltInkSoft)
            }

            SettingsRow(
                title: "Onboarding erneut anzeigen",
                iconSystemName: "questionmark.circle",
                tint: .boltTeal
            ) {
                onboardingState.reset()
                dismiss()
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }

            SettingsRow(
                title: "Open-Source-Lizenzen",
                iconSystemName: "doc.text",
                tint: .boltTeal,
                isLast: true
            ) {
                isShowingLicenses = true
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.boltInkFaint)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
            Text("Lanicode · Stromer")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
            return .boltOk
        case .off, .unauthorized, .unsupported, .failed:
            return .boltBad
        case .idle, .resetting, .unknown:
            return .boltInkSoft
        }
    }

    private var isScannerActive: Bool {
        switch appModel.scannerState {
        case .scanning, .resetting:
            return true
        case .idle, .unauthorized, .off, .unsupported, .unknown, .failed:
            return false
        }
    }

    private var authorizationTitle: String {
        switch appModel.bluetoothAuthorization {
        case .allowed:
            return "Erlaubt"
        case .denied:
            return "Abgelehnt"
        case .restricted:
            return "Eingeschränkt"
        case .notDetermined:
            return "Ungefragt"
        case .unknown:
            return "Unbekannt"
        }
    }

    private var authorizationSymbol: String {
        switch appModel.bluetoothAuthorization {
        case .allowed:
            return "diamond.fill"
        case .denied, .restricted:
            return "xmark"
        case .notDetermined, .unknown:
            return "questionmark"
        }
    }

    private var authorizationColor: Color {
        switch appModel.bluetoothAuthorization {
        case .allowed:
            return .boltTealDeep
        case .denied, .restricted:
            return .boltBad
        case .notDetermined, .unknown:
            return .boltInkSoft
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func toggleScanner() async {
        if isScannerActive {
            await appModel.stopScanner()
        } else {
            await appModel.restartScanner()
        }
    }
}

private struct SettingsScannerSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn ? Color.boltTeal : Color.boltHair)
                    .frame(width: 30, height: 16)

                Rectangle()
                    .fill(Color.boltCream)
                    .frame(width: 10, height: 10)
                    .padding(.horizontal, 3)
            }
            .frame(width: 30, height: 16)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    let iconSystemName: String?
    let tint: Color
    let isLast: Bool
    let action: (() -> Void)?
    let trailing: Trailing

    init(
        title: String,
        iconSystemName: String? = nil,
        tint: Color = .boltInk,
        isLast: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.tint = tint
        self.isLast = isLast
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if let iconSystemName {
                        Image(systemName: iconSystemName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                            .frame(width: 20)
                    }

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.boltInk)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 12)

                    trailing
                        .foregroundStyle(Color.boltInkSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                if !isLast {
                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StatusPill: View {
    let title: String
    let color: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .heavy))
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
        }
        .foregroundStyle(color)
    }
}

private struct PrivacyItem: View {
    let title: String
    let description: String
    var isLast = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.boltYellow)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.boltInk)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.boltInkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)

            if !isLast {
                Rectangle()
                    .fill(Color.boltHair2)
                    .frame(height: 1)
            }
        }
    }
}
