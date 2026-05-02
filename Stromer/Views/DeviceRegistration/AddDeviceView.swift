import Observation
import StromerScanner
import SwiftUI
import UIKit

@Observable
final class AddDeviceViewModel {
    var name = ""
    var advertisementKey = ""
    var kind: DeviceRegistrationKind = .smartShunt
    var errorMessage: String?

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && DeviceKeyValidator.isValid(DeviceKeyValidator.normalized(advertisementKey))
    }
}

private enum AddDeviceMode: String, CaseIterable, Identifiable {
    case nearby
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nearby:
            return "In der Nähe"
        case .manual:
            return "Manuell"
        }
    }
}

private enum DiscoverySheet: Identifiable {
    case registration(DiscoveredDevice)
    case unsupported(DiscoveredDevice)

    var id: String {
        switch self {
        case let .registration(device):
            return "registration-\(device.id.uuidString)"
        case let .unsupported(device):
            return "unsupported-\(device.id.uuidString)"
        }
    }
}

private enum DiscoveryEmptyState {
    case bluetoothOff
    case bluetoothPermissionDenied
    case bluetoothUnsupported
    case searching
    case noResults
}

struct AddDeviceView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddDeviceViewModel()
    @State private var saveFeedback = false
    @State private var mode: AddDeviceMode = .nearby
    @State private var didChooseInitialMode = false
    @State private var discoverySheet: DiscoverySheet?
    @State private var discoveryOpenedAt = Date()
    @State private var discoveryNow = Date()

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                addDeviceNavBar

                BoltSegmentedControl(selection: $mode)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                Group {
                    if mode == .nearby {
                        discoveryContent
                    } else {
                        manualContent
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            chooseInitialModeIfNeeded()
            while !Task.isCancelled {
                discoveryNow = Date()
                appModel.refreshDiscovery()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .nearby {
                resetDiscoveryEmptyStateTimer()
            }
        }
        .onChange(of: appModel.canUseDiscovery) { _, canUseDiscovery in
            chooseInitialModeIfNeeded()
            if !canUseDiscovery, mode == .nearby {
                resetDiscoveryEmptyStateTimer()
            }
        }
        .onDisappear {
            appModel.clearDiscovery()
        }
        .sheet(item: $discoverySheet) { sheet in
            switch sheet {
            case let .registration(device):
                NavigationStack {
                    DiscoveryRegistrationStepView(device: device) { device, name, key in
                        try appModel.registerDiscoveredDevice(
                            device,
                            name: name,
                            advertisementKeyHex: key
                        )
                        appModel.refreshDiscovery()
                        saveFeedback.toggle()
                        dismiss()
                    }
                }
            case let .unsupported(device):
                UnsupportedDiscoveryDeviceSheet(device: device)
            }
        }
        .sensoryFeedback(.success, trigger: saveFeedback)
    }

    private var addDeviceNavBar: some View {
        HStack {
            Button("ABBRUCH") {
                dismiss()
            }
            .font(.system(size: 12, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Color.boltTeal)
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 7) {
                BoltSLockup(size: 20)
                Text("GERÄT HINZUFÜGEN")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.boltInk)
            }

            Spacer()

            Color.clear
                .frame(width: 72, height: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var manualContent: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BoltSection(header: "Gerät") {
                    VStack(spacing: 0) {
                        manualNameField(text: $viewModel.name)

                        Rectangle()
                            .fill(Color.boltHair2)
                            .frame(height: 1)

                        Picker("Gerätetyp", selection: $viewModel.kind) {
                            ForEach(DeviceRegistrationKind.allCases) { kind in
                                Text(kind.title)
                                    .tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.boltTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                BoltSection(
                    header: "Advertisement Key",
                    footer: "Der Key bleibt im iOS-Keychain. Widgets lesen später nur entschlüsselte Snapshots aus der App Group."
                ) {
                    KeyInputField(text: $viewModel.advertisementKey)
                        .padding(14)
                }

                BoltSection(header: "Key in VictronConnect finden") {
                    KeyHelpText()
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                BoltPrimary("Gerät hinzufügen", showsBolt: true) {
                    save()
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.45)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private func manualNameField(text: Binding<String>) -> some View {
        TextField("Name", text: text)
            .textInputAutocapitalization(.words)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.boltInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
    }

    private var discoveryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScanningIndicator(isScanning: appModel.scannerState == .scanning)
                    .padding(.horizontal, 18)

                if let emptyState = discoveryEmptyState {
                    discoveryEmptyStateView(emptyState)
                        .padding(.horizontal, 18)
                } else if !appModel.discoveredDevices.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(appModel.discoveredDevices) { device in
                            DiscoveryDeviceRow(device: device) {
                                handleDiscoveryTap(device)
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    Text("Liste wird nicht gespeichert. Einträge werden nach kurzer Zeit ausgegraut und entfernt.")
                        .font(.system(size: 11).italic())
                        .foregroundStyle(Color.boltInkSoft)
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 28)
        }
        .refreshable {
            await appModel.restartScanner()
            appModel.refreshDiscovery()
        }
    }

    private var discoveryEmptyState: DiscoveryEmptyState? {
        switch appModel.bluetoothAuthorization {
        case .denied, .restricted:
            return .bluetoothPermissionDenied
        case .allowed, .notDetermined, .unknown:
            break
        }

        switch appModel.scannerState {
        case .off:
            return .bluetoothOff
        case .unauthorized:
            return .bluetoothPermissionDenied
        case .unsupported:
            return .bluetoothUnsupported
        case .idle, .scanning, .resetting, .unknown, .failed:
            break
        }

        guard appModel.discoveredDevices.isEmpty else {
            return nil
        }

        return discoveryNow.timeIntervalSince(discoveryOpenedAt) < 10 ? .searching : .noResults
    }

    @ViewBuilder
    private func discoveryEmptyStateView(_ state: DiscoveryEmptyState) -> some View {
        switch state {
        case .bluetoothOff:
            StromerEmptyStateView(
                iconSystemName: "bluetooth.slash",
                title: "Bluetooth ist ausgeschaltet",
                description: "Schalte Bluetooth ein, damit Stromer Geräte in der Nähe finden kann.",
                action: .init(label: "Einstellungen öffnen", perform: openSettings)
            )
        case .bluetoothPermissionDenied:
            StromerEmptyStateView(
                iconSystemName: "hand.raised",
                title: "Bluetooth-Zugriff abgelehnt",
                description: "Erlaube Bluetooth in den iOS-Einstellungen oder füge das Gerät manuell hinzu.",
                action: .init(label: "Einstellungen öffnen", perform: openSettings)
            )
        case .bluetoothUnsupported:
            StromerEmptyStateView(
                iconSystemName: "dot.radiowaves.right",
                title: "Bluetooth nicht verfügbar",
                description: "Dieses Gerät unterstützt Bluetooth Low Energy nicht. Du kannst ein Victron-Gerät weiterhin manuell hinzufügen.",
                action: .init(label: "Manuell hinzufügen") {
                    mode = .manual
                }
            )
        case .searching:
            StromerEmptyStateView(
                iconSystemName: "antenna.radiowaves.left.and.right",
                title: "Suche läuft",
                description: "Stromer sucht nach Victron-Geräten mit aktivem Instant Readout."
            )
        case .noResults:
            StromerEmptyStateView(
                iconSystemName: "magnifyingglass",
                title: "Keine Victron-Geräte gefunden",
                description: "Prüfe, ob Bluetooth aktiv ist, das Gerät in Reichweite ist und Instant Readout in VictronConnect eingeschaltet ist.",
                action: .init(label: "Manuell hinzufügen") {
                    mode = .manual
                }
            )
        }
    }

    private func save() {
        do {
            try appModel.registerDevice(
                name: viewModel.name,
                advertisementKeyHex: viewModel.advertisementKey,
                kind: viewModel.kind
            )
            saveFeedback.toggle()
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func chooseInitialModeIfNeeded() {
        guard !didChooseInitialMode else {
            return
        }

        mode = appModel.canUseDiscovery ? .nearby : .manual
        if mode == .nearby {
            resetDiscoveryEmptyStateTimer()
        }
        didChooseInitialMode = true
    }

    private func resetDiscoveryEmptyStateTimer() {
        discoveryOpenedAt = Date()
        discoveryNow = discoveryOpenedAt
    }

    private func handleDiscoveryTap(_ device: DiscoveredDevice) {
        guard !device.isRegistered else {
            return
        }

        switch device.supportStatus {
        case .supported, .plannedPhase37:
            discoverySheet = .registration(device)
        case .outOfScope:
            discoverySheet = .unsupported(device)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

private struct BoltSegmentedControl: View {
    @Binding var selection: AddDeviceMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AddDeviceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(selection == mode ? Color.boltCream : Color.boltInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selection == mode ? Color.boltInk : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.boltInk, lineWidth: 1))
    }
}

private struct ScanningIndicator: View {
    let isScanning: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.boltTeal)
                .frame(width: 14, height: 14)
                .opacity(isScanning ? (pulse ? 1 : 0.4) : 0.35)
                .animation(
                    isScanning
                        ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            Text(isScanning ? "SCANNT · VICTRON INSTANT READOUT" : "SCAN · PAUSIERT")
                .font(.system(size: 10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Color.boltTealDeep)

            Spacer()
        }
        .padding(.vertical, 6)
        .onAppear {
            pulse = true
        }
    }
}

private struct DiscoveryRegistrationStepView: View {
    @Environment(\.dismiss) private var dismiss
    let device: DiscoveredDevice
    let onSave: (DiscoveredDevice, String, String) throws -> Void

    @State private var viewModel: DiscoveryRegistrationViewModel
    @State private var saveFeedback = false

    init(
        device: DiscoveredDevice,
        onSave: @escaping (DiscoveredDevice, String, String) throws -> Void
    ) {
        self.device = device
        self.onSave = onSave
        _viewModel = State(initialValue: DiscoveryRegistrationViewModel(device: device))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                keyEntryNavBar(canSave: viewModel.canSave)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        BoltSection(header: "Gerät") {
                            VStack(spacing: 0) {
                                TextField("Name", text: $viewModel.name)
                                    .textInputAutocapitalization(.words)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 13)

                                BoltInfoRow(title: "Modell", value: device.estimatedModelName)
                                BoltInfoRow(title: "Typ", value: device.estimatedDeviceType.title)
                                BoltInfoRow(
                                    title: "Peripheral-ID",
                                    value: device.peripheralID.uuidString,
                                    isMono: true
                                )
                            }
                        }

                        BoltSection(
                            header: "Advertisement Key",
                            footer: "Der Key bleibt im iOS-Schlüsselbund. Stromer prüft ihn gegen das zuletzt empfangene Advertisement."
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                if device.supportStatus == .plannedPhase37 {
                                    DiscoveryInfoBox()
                                }

                                KeyInputField(text: $viewModel.advertisementKey)
                            }
                            .padding(14)
                        }

                        BoltSection(header: "Key in VictronConnect finden") {
                            KeyHelpText()
                        }

                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: saveFeedback)
    }

    private func keyEntryNavBar(canSave: Bool) -> some View {
        HStack {
            Button("ZURÜCK") {
                dismiss()
            }
            .font(.system(size: 12, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Color.boltTeal)
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 7) {
                BoltSLockup(size: 20)
                Text("KEY EINGEBEN")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.boltInk)
            }

            Spacer()

            Button("SICHERN") {
                save()
            }
            .font(.system(size: 12, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(canSave ? Color.boltTeal : Color.boltInkFaint)
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func save() {
        do {
            try onSave(device, viewModel.name, viewModel.advertisementKey)
            saveFeedback.toggle()
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

@Observable
private final class DiscoveryRegistrationViewModel {
    var name: String
    var advertisementKey = ""
    var errorMessage: String?

    init(device: DiscoveredDevice) {
        name = device.localName?.isEmpty == false
            ? device.localName ?? device.estimatedModelName
            : device.estimatedModelName
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && DeviceKeyValidator.isValid(DeviceKeyValidator.normalized(advertisementKey))
    }
}

private struct DiscoveryDeviceRow: View {
    let device: DiscoveredDevice
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                kindTile

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.estimatedModelName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.boltInk)
                        .lineLimit(2)

                    Text("\(device.estimatedDeviceType.title) · \(device.rssi) dBm · \(lastSeenText)")
                        .font(.boltMono(11))
                        .foregroundStyle(Color.boltInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                Text(statusTitle)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(statusColor, lineWidth: 1))
            }
            .padding(12)
            .background(Color.boltPaper)
            .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(device.isRegistered || device.supportStatus == .outOfScope)
        .opacity(rowOpacity)
        .accessibilityLabel(accessibilityLabel)
    }

    private var kindTile: some View {
        ZStack {
            Rectangle()
                .fill(tileColor)
                .frame(width: 36, height: 36)

            Image(systemName: device.estimatedDeviceType.systemImageName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tileForeground)
        }
    }

    private var tileColor: Color {
        switch device.estimatedDeviceType {
        case .batteryMonitor:
            return .boltTeal
        case .solarCharger:
            return .boltYellow
        case .dcDcConverter:
            return .boltTeal
        default:
            return .boltHair2
        }
    }

    private var tileForeground: Color {
        device.estimatedDeviceType == .solarCharger ? .boltInkFixed : .boltCream
    }

    private var statusTitle: String {
        if device.isRegistered {
            return "HINZUGEFÜGT"
        }

        switch device.supportStatus {
        case .supported:
            return "HINZUFÜGEN"
        case .plannedPhase37:
            return "DECODING FOLGT"
        case .outOfScope:
            return "NICHT UNTERSTÜTZT"
        }
    }

    private var statusColor: Color {
        if device.isRegistered {
            return .boltTealDeep
        }

        switch device.supportStatus {
        case .supported:
            return .boltTeal
        case .plannedPhase37:
            return .boltWarn
        case .outOfScope:
            return .boltInkFaint
        }
    }

    private var rowOpacity: Double {
        if device.displayState == .dimmed || device.isRegistered {
            return 0.55
        }
        return 1
    }

    private var lastSeenText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(device.lastSeenAt)))
        if seconds < 30 {
            return "vor \(seconds) Sek."
        }
        if seconds < 90 {
            return "zuletzt vor \(seconds) Sek."
        }
        return "zuletzt vor \(seconds / 60) Min."
    }

    private var accessibilityLabel: String {
        "\(device.estimatedModelName), \(device.estimatedDeviceType.title), \(statusTitle)"
    }
}

private struct DiscoveryInfoBox: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.boltWarn)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daten-Decoding folgt")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.boltInk)
                Text("Du kannst dieses Modell jetzt registrieren. Live-Werte erscheinen automatisch nach einem späteren Update der App.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.boltInkSoft)
            }
        }
        .padding(12)
        .background(Color.boltYellow.opacity(0.16))
        .overlay(Rectangle().stroke(Color.boltWarn.opacity(0.45), lineWidth: 1))
    }
}

private struct KeyHelpText: View {
    private let steps: [(String, String)] = [
        ("01", "VictronConnect öffnen und Gerät auswählen."),
        ("02", "Geräteeinstellungen -> 'Instant Readout'."),
        ("03", "Advertisement Key anzeigen lassen."),
        ("04", "Hex-Key kopieren und hier einfügen.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.0) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text(step.0)
                        .font(.boltMono(14))
                        .fontWeight(.heavy)
                        .foregroundStyle(Color.boltTeal)
                        .frame(width: 32, alignment: .leading)

                    Text(step.1)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.boltInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                        .padding(.leading, 58)
                }
            }
        }
    }
}

private struct UnsupportedDiscoveryDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: DiscoveredDevice

    var body: some View {
        NavigationStack {
            ZStack {
                BoltBackground()

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color.boltWarn)

                    BoltEyebrow("Nicht unterstützt", color: .boltWarn)

                    Text("Dieses Gerät wird derzeit nicht unterstützt.")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color.boltInk)

                    Text("\(device.estimatedModelName) sendet Victron-Advertisements, gehört aber zu einer Gerätefamilie außerhalb des aktuellen Stromer-Scopes.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.boltInkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    BoltPrimary("OK") {
                        dismiss()
                    }

                    Spacer()
                }
                .padding(22)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct BoltInfoRow: View {
    let title: String
    let value: String
    var isMono = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.boltInk)

            Spacer()

            Text(value)
                .font(isMono ? .boltMono(11) : .system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boltInkSoft)
                .multilineTextAlignment(.trailing)
                .lineLimit(isMono ? 2 : 1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.boltHair2)
                .frame(height: 1)
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.boltBad)

            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boltBad)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltBad.opacity(0.45), lineWidth: 1))
    }
}
