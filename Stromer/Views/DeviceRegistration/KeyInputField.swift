import SwiftUI

enum DeviceKeyValidator {
    static func normalized(_ input: String) -> String {
        input
            .filter { !$0.isWhitespace }
            .lowercased()
    }

    static func isValid(_ input: String) -> Bool {
        input.count == 32 && input.allSatisfy(\.isHexDigit)
    }
}

struct KeyInputField: View {
    @Binding var text: String

    private var normalizedText: String {
        DeviceKeyValidator.normalized(text)
    }

    private var isValid: Bool {
        DeviceKeyValidator.isValid(normalizedText)
    }

    private var borderColor: Color {
        if normalizedText.isEmpty {
            return .secondary.opacity(0.35)
        }
        return isValid ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Advertisement Key", text: $text)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .onChange(of: text) { _, newValue in
                    let normalized = DeviceKeyValidator.normalized(newValue)
                    if normalized != newValue {
                        text = normalized
                    }
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1.2)
                }

            HStack {
                Label(
                    isValid ? "Key gültig" : "Exakt 32 Hex-Zeichen",
                    systemImage: isValid ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .foregroundStyle(isValid ? .green : .secondary)

                Spacer()

                Text("\(normalizedText.count)/32")
                    .monospacedDigit()
                    .foregroundStyle(isValid ? .green : .secondary)
            }
            .font(.caption)
        }
    }
}
