import CoreLocation
import StromerScanner
import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @Bindable var settings: NotificationSettings
    @ObservedObject var sunsetService: SunsetService

    let scheduler: DailyInsightScheduler?
    let notificationCoordinator: NotificationCoordinator
    let devices: [RegisteredDevice]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        masterSection
                            .padding(.horizontal, 18)

                        if settings.notificationsEnabled {
                            typeSection
                                .padding(.horizontal, 18)

                            if settings.dailyInsightEnabled {
                                dailyInsightSection
                                    .padding(.horizontal, 18)
                            }

                            if settings.thresholdNotificationsEnabled {
                                thresholdSection
                                    .padding(.horizontal, 18)
                            }
                        } else {
                            disabledHint
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings.notificationsEnabled) { _, isEnabled in
            Task {
                if isEnabled {
                    _ = await notificationCoordinator.requestAuthorization()
                }
                await scheduler?.reschedule()
            }
        }
        .onChange(of: settings.dailyInsightEnabled) { _, _ in
            Task { await scheduler?.reschedule() }
        }
        .onChange(of: settings.dailyInsightUseSunset) { _, useSunset in
            if useSunset {
                sunsetService.requestPermission()
                sunsetService.requestSingleLocationUpdate()
            }
            Task { await scheduler?.reschedule() }
        }
        .onChange(of: settings.dailyInsightFixedTime) { _, _ in
            Task { await scheduler?.reschedule() }
        }
        .onChange(of: sunsetService.todaySunset) { _, _ in
            Task { await scheduler?.reschedule() }
        }
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text("< ZURÜCK")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.boltTeal)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                BoltSLockup(size: 20)
                Text("Benachrichtigungen".uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.boltInk)
            }

            Spacer()
            Spacer(minLength: 72)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var masterSection: some View {
        BoltSection(header: "Benachrichtigungen") {
            SettingsToggleRow(
                title: "Benachrichtigungen aktivieren",
                subtitle: "Lokale Hinweise, keine Server-Pushes.",
                isOn: $settings.notificationsEnabled,
                isLast: true
            )
        }
    }

    private var disabledHint: some View {
        BoltSection(footer: "Stromer fragt die iOS-Berechtigung erst an, wenn du Benachrichtigungen hier aktivierst.") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Noch deaktiviert")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.boltInk)
                Text("Aktiviere Benachrichtigungen, um Schwellwerte, Geräte-Verlust und Tagesfazit einzurichten.")
                    .font(.boltBody)
                    .foregroundStyle(Color.boltInkSoft)
            }
            .padding(16)
        }
    }

    private var typeSection: some View {
        BoltSection(header: "Typen") {
            SettingsToggleRow(
                title: "Schwellwert-Warnungen",
                subtitle: "SoC, Spannung, Temperatur, Solar-Peaks.",
                isOn: $settings.thresholdNotificationsEnabled
            )

            SettingsToggleRow(
                title: "Ereignisse",
                subtitle: "Volladung und Ladezustand-Wechsel.",
                isOn: $settings.eventNotificationsEnabled
            )

            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Geräte-Verlust",
                    subtitle: "Hinweis beim nächsten App-Start.",
                    isOn: $settings.deviceLossNotificationsEnabled,
                    isLast: !settings.deviceLossNotificationsEnabled
                )

                if settings.deviceLossNotificationsEnabled {
                    HStack {
                        Text("Schwelle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.boltInk)
                        Spacer()
                        Stepper(
                            "\(settings.deviceLossThresholdHours) h",
                            value: $settings.deviceLossThresholdHours,
                            in: 1...24
                        )
                        .font(.boltMono(12))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                }
            }

            SettingsToggleRow(
                title: "Tagesfazit",
                subtitle: "Kurzer Abend-Hinweis mit lokalen Daten.",
                isOn: $settings.dailyInsightEnabled,
                isLast: true
            )
        }
    }

    private var dailyInsightSection: some View {
        BoltSection(header: "Tagesfazit-Zeit") {
            SettingsToggleRow(
                title: "Sonnenuntergang verwenden",
                subtitle: "Standort nur grob und nur bei Nutzung.",
                isOn: $settings.dailyInsightUseSunset,
                isLast: !settings.dailyInsightUseSunset
            )

            if settings.dailyInsightUseSunset {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(sunsetText)
                            .font(.boltMono(12))
                            .foregroundStyle(Color.boltInkSoft)
                        Spacer()
                        Button("Standort erlauben") {
                            sunsetService.requestPermission()
                            sunsetService.requestSingleLocationUpdate()
                            Task { await scheduler?.reschedule() }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.boltTeal)
                    }

                    if locationNeedsSettings {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } label: {
                            Text("In iOS-Einstellungen aktivieren".uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(Color.boltBad)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            } else {
                DatePicker(
                    "Feste Zeit",
                    selection: fixedTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if devices.isEmpty {
                BoltSection(header: "Schwellwerte") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Noch keine Geräte")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color.boltInk)
                        Text("Füge ein Gerät hinzu, um Schwellwerte zu konfigurieren.")
                            .font(.boltBody)
                            .foregroundStyle(Color.boltInkSoft)
                    }
                    .padding(16)
                }
            } else {
                ForEach(devices) { device in
                    BoltSection(header: device.name) {
                        VStack(spacing: 0) {
                            let types = thresholdTypes(for: device)
                            ForEach(Array(types.enumerated()), id: \.element.id) { index, type in
                                ThresholdSettingsRow(
                                    settings: settings,
                                    deviceID: device.id,
                                    type: type,
                                    isLast: index == types.count - 1
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var fixedTimeBinding: Binding<Date> {
        Binding {
            let components = settings.dailyInsightFixedTime
            return Calendar.current.date(
                bySettingHour: components.hour ?? 21,
                minute: components.minute ?? 0,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { date in
            settings.dailyInsightFixedTime = Calendar.current.dateComponents(
                [.hour, .minute],
                from: date
            )
        }
    }

    private var sunsetText: String {
        guard let todaySunset = sunsetService.todaySunset else {
            switch sunsetService.permissionStatus {
            case .notDetermined:
                return "Standort noch nicht freigegeben"
            case .denied, .restricted:
                return "Standortzugriff nicht erlaubt"
            default:
                return "Sonnenuntergang wird berechnet"
            }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeStyle = .short
        return "Heute ca. \(formatter.string(from: todaySunset)) in deiner Region"
    }

    private var locationNeedsSettings: Bool {
        sunsetService.permissionStatus == .denied ||
            sunsetService.permissionStatus == .restricted
    }

    private func thresholdTypes(for device: RegisteredDevice) -> [NotificationSettings.ThresholdType] {
        switch device.recordType {
        case 0x01:
            return [.pvPowerPeak]
        case 0x04:
            return [.dcDcOutputLow]
        default:
            return [.socLow, .socHigh, .voltageLow, .voltageHigh, .temperatureHigh]
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var isLast = false

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.boltInk)
                    if let subtitle {
                        Text(subtitle)
                            .font(.boltMono(11))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                }
            }
            .tint(.boltTeal)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if !isLast {
                Rectangle()
                    .fill(Color.boltHair2)
                    .frame(height: 1)
            }
        }
    }
}

private struct ThresholdSettingsRow: View {
    @Bindable var settings: NotificationSettings
    let deviceID: UUID
    let type: NotificationSettings.ThresholdType
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: enabledBinding) {
                    Text(type.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.boltInk)
                }
                .tint(.boltTeal)
            }

            if settings.isThresholdEnabled(for: deviceID, type: type) {
                Slider(
                    value: valueBinding,
                    in: type.range,
                    step: type.step
                )
                .tint(.boltTeal)

                Text(valueText)
                    .font(.boltMono(12))
                    .foregroundStyle(Color.boltInkSoft)
            }

            if !isLast {
                Rectangle()
                    .fill(Color.boltHair2)
                    .frame(height: 1)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var enabledBinding: Binding<Bool> {
        Binding {
            settings.isThresholdEnabled(for: deviceID, type: type)
        } set: { isEnabled in
            settings.setThresholdEnabled(isEnabled, for: deviceID, type: type)
        }
    }

    private var valueBinding: Binding<Double> {
        Binding {
            settings.storedThreshold(for: deviceID, type: type)
        } set: { value in
            settings.setThreshold(value, for: deviceID, type: type)
        }
    }

    private var valueText: String {
        let value = settings.storedThreshold(for: deviceID, type: type)
        switch type.step {
        case 1:
            return "\(Int(value.rounded())) \(type.unit)"
        default:
            return String(format: "%.1f %@", value, type.unit)
        }
    }
}
