import Observation
import SwiftUI

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

struct AddDeviceView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddDeviceViewModel()
    @State private var saveFeedback = false

    var body: some View {
        @Bindable var viewModel = viewModel

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. VictronConnect öffnen und das Gerät auswählen.")
                    Text("2. In den Geräteeinstellungen „Instant Readout“ öffnen.")
                    Text("3. Advertisement Key anzeigen lassen.")
                    Text("4. Den 32-stelligen Hex-Key kopieren und hier einfügen.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
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
}
