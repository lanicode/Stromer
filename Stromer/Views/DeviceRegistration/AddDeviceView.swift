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

struct AddDeviceView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddDeviceViewModel()
    @State private var saveFeedback = false
    @State private var mode: AddDeviceMode = .nearby
    @State private var didChooseInitialMode = false
    @State private var discoverySheet: DiscoverySheet?

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            Picker("Hinzufügen", selection: $mode) {
                ForEach(AddDeviceMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .padding(.bottom, 10)

            if mode == .nearby {
                discoveryContent
            } else {
                Form {
                    Section("Gerät") {
                        TextField("Name", text: $viewModel.name)
                            .textInputAutocapitalization(.words)

                        Picker("Gerätetyp", selection: $viewModel.kind) {
                            ForEach(DeviceRegistrationKind.allCases) { kind in
                                Text(kind.title)
                                    .tag(kind)
                            }
                        }
                    }

                    Section {
                        KeyInputField(text: $viewModel.advertisementKey)
                    } header: {
                        Text("Advertisement Key")
                    } footer: {
                        Text("Der Key bleibt im iOS-Keychain. Widgets lesen später nur entschlüsselte Snapshots aus der App Group.")
                    }

                    Section("Key in VictronConnect finden") {
                        KeyHelpText()
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Gerät hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if mode == .manual {
                    Button("Sichern") {
                        save()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .task {
            chooseInitialModeIfNeeded()
            while !Task.isCancelled {
                appModel.refreshDiscovery()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: appModel.canUseDiscovery) { _, canUseDiscovery in
            chooseInitialModeIfNeeded()
            if !canUseDiscovery, mode == .nearby {
                mode = .manual
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

    private var discoveryContent: some View {
        Group {
            if !appModel.canUseDiscovery {
                ContentUnavailableView {
                    Label("Suche nicht möglich", systemImage: "bluetooth.slash")
                } description: {
                    Text("Bluetooth ist ausgeschaltet oder Stromer darf nicht scannen. Du kannst das Gerät weiterhin manuell hinzufügen.")
                } actions: {
                    if appModel.bluetoothAuthorization.needsSettingsAction {
                        Button("Einstellungen öffnen") {
                            openSettings()
                        }
                    }
                }
            } else if appModel.discoveredDevices.isEmpty {
                ContentUnavailableView {
                    Label("Keine Victron-Geräte gefunden", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text("Stromer sucht nach Victron-Advertisements in der Nähe. Prüfe, ob Instant Readout in VictronConnect aktiv ist.")
                }
            } else {
                List {
                    Section {
                        ForEach(appModel.discoveredDevices) { device in
                            DiscoveryDeviceRow(device: device) {
                                handleDiscoveryTap(device)
                            }
                        }
                    } header: {
                        HStack {
                            Text("In der Nähe")
                            Spacer()
                            if appModel.scannerState == .scanning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    } footer: {
                        Text("Die Liste wird nicht gespeichert. Einträge werden nach kurzer Zeit ausgegraut und danach entfernt.")
                    }
                }
                .refreshable {
                    await appModel.restartScanner()
                    appModel.refreshDiscovery()
                }
            }
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
        didChooseInitialMode = true
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

        Form {
            Section("Gerät") {
                TextField("Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)

                LabeledContent("Modell") {
                    Text(device.estimatedModelName)
                }

                LabeledContent("Typ") {
                    Text(device.estimatedDeviceType.title)
                }

                LabeledContent("Peripheral-ID") {
                    Text(device.peripheralID.uuidString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section {
                if device.supportStatus == .plannedPhase37 {
                    DiscoveryInfoBox()
                }

                KeyInputField(text: $viewModel.advertisementKey)
            } header: {
                Text("Advertisement Key")
            } footer: {
                Text("Bei unterstützten Geräten prüft Stromer den Key gegen das zuletzt empfangene Advertisement.")
            }

            Section("Key in VictronConnect finden") {
                KeyHelpText()
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Key eingeben")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    save()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .sensoryFeedback(.success, trigger: saveFeedback)
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
                Image(systemName: device.estimatedDeviceType.systemImageName)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(device.estimatedModelName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if device.isRegistered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Text("\(device.estimatedDeviceType.title) · RSSI \(device.rssi) dBm · \(lastSeenText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)

                if !device.isRegistered {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(device.isRegistered)
        .opacity(device.displayState == .dimmed ? 0.45 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var statusTitle: String {
        device.isRegistered ? "Hinzugefügt" : device.supportStatus.title
    }

    private var statusColor: Color {
        if device.isRegistered {
            return .green
        }

        switch device.supportStatus {
        case .supported:
            return .blue
        case .plannedPhase37:
            return .orange
        case .outOfScope:
            return .gray
        }
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
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daten-Decoding folgt")
                    .font(.subheadline.weight(.semibold))
                Text("Du kannst dieses Modell jetzt registrieren. Live-Werte erscheinen automatisch nach einem späteren Update der App.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct KeyHelpText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. VictronConnect öffnen und das Gerät auswählen.")
            Text("2. In den Geräteeinstellungen „Instant Readout“ öffnen.")
            Text("3. Advertisement Key anzeigen lassen.")
            Text("4. Den 32-stelligen Hex-Key kopieren und hier einfügen.")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

private struct UnsupportedDiscoveryDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: DiscoveredDevice

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Dieses Gerät wird derzeit nicht unterstützt.", systemImage: "exclamationmark.triangle")
            } description: {
                Text("\(device.estimatedModelName) sendet Victron-Advertisements, gehört aber zu einer Gerätefamilie außerhalb des aktuellen Stromer-Scopes.")
            } actions: {
                Button("OK") {
                    dismiss()
                }
            }
            .navigationTitle("Nicht unterstützt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
