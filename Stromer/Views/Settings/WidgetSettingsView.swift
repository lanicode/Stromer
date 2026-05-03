import StromerScanner
import SwiftUI
import WidgetKit

struct WidgetSettingsView: View {
    let devices: [RegisteredDevice]

    @Environment(\.dismiss) private var dismiss
    @State private var preferences: StromerWidgetPreferences = .default
    @State private var saveErrorMessage: String?

    private let preferenceStore = try? AppGroupWidgetPreferenceStore()

    private var sortedDevices: [RegisteredDevice] {
        devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        modeSection
                            .padding(.horizontal, 18)

                        if preferences.mediumMode == .manual {
                            manualDeviceSection
                                .padding(.horizontal, 18)
                        }

                        previewSection
                            .padding(.horizontal, 18)

                        if let saveErrorMessage {
                            errorSection(saveErrorMessage)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            preferences = preferenceStore?.loadPreferences() ?? .default
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
                Text("Widget".uppercased())
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

    private var modeSection: some View {
        BoltSection(
            header: "Mittelgroßes Widget",
            footer: "Diese Einstellung gilt für das mittelgroße Home-Screen-Widget. Kleine Widgets nutzen weiter die iOS-Widget-Auswahl."
        ) {
            VStack(spacing: 0) {
                ForEach(Array(StromerMediumWidgetMode.allCases.enumerated()), id: \.element) { index, mode in
                    WidgetModeRow(
                        mode: mode,
                        isSelected: preferences.mediumMode == mode,
                        isLast: index == StromerMediumWidgetMode.allCases.count - 1
                    ) {
                        preferences.mediumMode = mode
                        savePreferences()
                    }
                }
            }
        }
    }

    private var manualDeviceSection: some View {
        BoltSection(
            header: "Geräte",
            footer: "Wähle bis zu drei Geräte. Die Reihenfolge entspricht der Auswahl; tippe erneut, um ein Gerät zu entfernen."
        ) {
            if sortedDevices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Noch keine Geräte")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.boltInk)
                    Text("Füge zuerst ein Victron-Gerät hinzu, dann kannst du das Widget manuell belegen.")
                        .font(.boltBody)
                        .foregroundStyle(Color.boltInkSoft)
                }
                .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedDevices.enumerated()), id: \.element.id) { index, device in
                        ManualWidgetDeviceRow(
                            device: device,
                            selectionIndex: preferences.mediumDeviceIDs.firstIndex(of: device.id),
                            isSelectionFull: preferences.mediumDeviceIDs.count >= StromerWidgetPreferences.maxMediumDevices,
                            isLast: index == sortedDevices.count - 1
                        ) {
                            toggleManualDevice(device.id)
                        }
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        BoltSection(header: "Vorschau") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.mediumMode.title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color.boltInk)
                        Text(previewDescription)
                            .font(.boltBody)
                            .foregroundStyle(Color.boltInkSoft)
                    }

                    Spacer(minLength: 12)

                    Text("\(selectedPreviewNames.count)/3")
                        .font(.boltMono(12))
                        .foregroundStyle(Color.boltInkSoft)
                }

                if !selectedPreviewNames.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(selectedPreviewNames.enumerated()), id: \.offset) { index, name in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.boltMono(11))
                                    .foregroundStyle(Color.boltTeal)
                                    .frame(width: 18, alignment: .leading)
                                Text(name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.boltInk)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func errorSection(_ message: String) -> some View {
        BoltSection(header: "Hinweis") {
            Text(message)
                .font(.boltBody)
                .foregroundStyle(Color.boltBad)
                .padding(16)
        }
    }

    private var previewDescription: String {
        switch preferences.mediumMode {
        case .automatic:
            return "Stromer verwendet die Widget-Geräteauswahl und füllt automatisch auf."
        case .manual:
            return preferences.mediumDeviceIDs.isEmpty
                ? "Noch keine manuelle Auswahl. Das Widget fällt auf die Geräteliste zurück."
                : "Das Widget zeigt deine manuelle Auswahl zuerst."
        default:
            return preferences.mediumMode.description
        }
    }

    private var selectedPreviewNames: [String] {
        let selectedIDs: [UUID]
        switch preferences.mediumMode {
        case .manual:
            selectedIDs = preferences.mediumDeviceIDs
        case .battery:
            selectedIDs = sortedDevices.filter { $0.recordType == 0x02 }.map(\.id)
        case .solar:
            selectedIDs = sortedDevices.filter { $0.recordType == 0x01 }.map(\.id)
        case .dcDc:
            selectedIDs = sortedDevices.filter { $0.recordType == 0x04 }.map(\.id)
        case .automatic:
            selectedIDs = []
        }

        if selectedIDs.isEmpty {
            return Array(sortedDevices.prefix(3)).map(\.name)
        }

        let selected = selectedIDs.compactMap { id in
            sortedDevices.first { $0.id == id }
        }
        let remaining = sortedDevices.filter { device in
            !selected.contains { $0.id == device.id }
        }
        return Array((selected + remaining).prefix(3)).map(\.name)
    }

    private func toggleManualDevice(_ id: UUID) {
        if let index = preferences.mediumDeviceIDs.firstIndex(of: id) {
            preferences.mediumDeviceIDs.remove(at: index)
        } else if preferences.mediumDeviceIDs.count < StromerWidgetPreferences.maxMediumDevices {
            preferences.mediumDeviceIDs.append(id)
        } else {
            return
        }

        savePreferences()
    }

    private func savePreferences() {
        saveErrorMessage = nil

        guard let preferenceStore else {
            saveErrorMessage = "Widget-Einstellung konnte nicht gespeichert werden."
            return
        }

        do {
            try preferenceStore.savePreferences(preferences)
            WidgetCenter.shared.reloadTimelines(ofKind: "StromerWidget")
        } catch {
            saveErrorMessage = "Widget-Einstellung konnte nicht gespeichert werden."
        }
    }
}

private struct WidgetModeRow: View {
    let mode: StromerMediumWidgetMode
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(isSelected ? Color.boltTeal : Color.boltHair2)
                        .frame(width: 8, height: 8)
                        .rotationEffect(.degrees(45))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.boltInk)
                        Text(mode.description)
                            .font(.boltBody)
                            .foregroundStyle(Color.boltInkSoft)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Color.boltTeal)
                    }
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

private struct ManualWidgetDeviceRow: View {
    let device: RegisteredDevice
    let selectionIndex: Int?
    let isSelectionFull: Bool
    let isLast: Bool
    let action: () -> Void

    private var isSelected: Bool {
        selectionIndex != nil
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Rectangle()
                            .fill(isSelected ? Color.boltTeal : Color.boltHair2)
                        if let selectionIndex {
                            Text("\(selectionIndex + 1)")
                                .font(.boltMono(11))
                                .foregroundStyle(Color.boltCream)
                        } else {
                            Image(systemName: "plus")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(isSelectionFull ? Color.boltInkFaint : Color.boltTeal)
                        }
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.boltInk)
                            .lineLimit(1)
                        Text(deviceTypeTitle)
                            .font(.boltMono(11))
                            .foregroundStyle(Color.boltInkSoft)
                    }

                    Spacer(minLength: 12)

                    if isSelected {
                        Text("gewählt".uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.boltTeal)
                    } else if isSelectionFull {
                        Text("max".uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.boltInkFaint)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .opacity(!isSelected && isSelectionFull ? 0.55 : 1)

                if !isLast {
                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var deviceTypeTitle: String {
        switch device.recordType {
        case 0x01:
            return "MPPT · Solar"
        case 0x02:
            return "Battery Monitor"
        case 0x04:
            return "DC/DC · Orion"
        default:
            return "Victron"
        }
    }
}
