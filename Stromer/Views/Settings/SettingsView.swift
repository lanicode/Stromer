import StromerScanner
import SwiftUI

struct SettingsView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAddDevice = false
    @State private var isShowingLicenses = false

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        bluetoothSection
                            .padding(.horizontal, 18)

                        notificationsSection
                            .padding(.horizontal, 18)

                        widgetSection
                            .padding(.horizontal, 18)

                        forecastSection
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

    private var bluetoothSection: some View {
        BoltSection(
            header: "Bluetooth",
            footer: "Stromer empfängt Werte automatisch wenn deine Geräte in Reichweite sind. Keine Aktion nötig."
        ) {
            SettingsRow(title: "Berechtigung") {
                StatusPill(
                    title: authorizationTitle,
                    color: authorizationColor,
                    symbol: authorizationSymbol
                )
            }

            SettingsRow(title: "Empfang", isLast: true) {
                ReceptionStatusPill(status: appModel.receptionStatusObserver.status)
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

    private var widgetSection: some View {
        BoltSection(
            header: "Widget",
            footer: "Lege fest, was das mittelgroße Home-Screen-Widget zeigen soll."
        ) {
            NavigationLink {
                WidgetSettingsView(devices: appModel.registeredDevices)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.boltTeal)
                            .frame(width: 20)

                        Text("Mittelgroßes Widget")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.boltInk)

                        Spacer(minLength: 12)

                        Text("Konfigurieren".uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.boltInkSoft)

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

    private var forecastSection: some View {
        BoltSection(
            header: "Prognose",
            footer: "Verwendet Standortdaten zur Berechnung lokaler Horizont-Abschattung. Daten werden lokal verarbeitet und nicht übermittelt."
        ) {
            SettingsForecastToggleRow(
                title: "Solar-Vorhersage anzeigen",
                isOn: Binding(
                    get: { appModel.forecastSettings.isForecastEnabled },
                    set: { appModel.forecastSettings.isForecastEnabled = $0 }
                )
            )

            SettingsForecastToggleRow(
                title: "Topographie berücksichtigen",
                subtitle: "Benötigt Standortfreigabe für Sonnenstand und Horizont.",
                isOn: Binding(
                    get: { appModel.forecastSettings.usesTopography },
                    set: { appModel.forecastSettings.usesTopography = $0 }
                ),
                isEnabled: appModel.forecastSettings.isForecastEnabled,
                isLast: true
            )
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
                    Text("Bluetooth-Status ist bereit. Füge ein Gerät hinzu, um Live-Werte zu sehen.")
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

    private var authorizationTitle: String {
        switch appModel.bluetoothAuthorization {
        case .allowed:
            return "Erlaubt"
        case .denied:
            return "Verweigert"
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

private struct ReceptionStatusPill: View {
    let status: ReceptionStatus

    var body: some View {
        HStack(spacing: 5) {
            Text(symbol)
            Text(title)
                .font(.boltMono(11))
                .tracking(1.4)
        }
        .font(.boltMono(11))
        .foregroundStyle(color)
    }

    private var title: String {
        switch status {
        case .live:
            return "LIVE"
        case .waiting:
            return "WARTET"
        case .offline:
            return "OFFLINE"
        }
    }

    private var symbol: String {
        switch status {
        case .live:
            return "⚡"
        case .waiting:
            return "◌"
        case .offline:
            return "◐"
        }
    }

    private var color: Color {
        switch status {
        case .live:
            return .boltTeal
        case .waiting:
            return .boltInk
        case .offline:
            return .boltInkSoft
        }
    }
}

private struct SettingsForecastToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var isEnabled = true
    var isLast = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isEnabled ? Color.boltInk : Color.boltInkFaint)

                    if let subtitle {
                        Text(subtitle)
                            .font(.boltMono(11))
                            .foregroundStyle(Color.boltInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.boltTeal)
                    .disabled(!isEnabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if !isLast {
                Rectangle()
                    .fill(Color.boltHair2)
                    .frame(height: 1)
            }
        }
        .opacity(isEnabled ? 1 : 0.55)
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
