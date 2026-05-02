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
            return .boltHair
        }
        return isValid ? .boltTeal : .boltBad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Advertisement Key", text: $text)
                .font(.boltMono(14))
                .tracking(1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .onChange(of: text) { _, newValue in
                    let normalized = DeviceKeyValidator.normalized(newValue)
                    if normalized != newValue {
                        text = normalized
                    }
                }
                .padding(12)
                .background(Color.boltCream)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 1.5))

            HStack {
                Rectangle()
                    .fill(isValid ? Color.boltTeal : Color.boltInkFaint)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))

                Text(isValid ? "KEY GÜLTIG" : "EXAKT 32 HEX-ZEICHEN")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(isValid ? Color.boltTealDeep : Color.boltInkSoft)

                Spacer()

                Text("\(normalizedText.count)/32")
                    .font(.boltMono(12))
                    .monospacedDigit()
                    .foregroundStyle(isValid ? Color.boltTealDeep : Color.boltInkSoft)
            }
        }
    }
}
