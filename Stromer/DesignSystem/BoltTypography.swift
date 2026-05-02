import SwiftUI

public extension Font {
    static func boltDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static let boltSectionTitle = Font.system(
        size: 30,
        weight: .heavy,
        design: .default
    )

    static let boltBodyBold = Font.system(
        size: 15,
        weight: .bold,
        design: .default
    )

    static let boltBody = Font.system(
        size: 14,
        weight: .regular,
        design: .default
    )

    static func boltMono(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    static let boltEyebrow = Font.system(
        size: 11,
        weight: .heavy,
        design: .default
    )
}

public struct BoltEyebrow: View {
    let text: String
    let color: Color

    public init(_ text: String, color: Color = .boltInkSoft) {
        self.text = text.uppercased()
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.boltEyebrow)
            .tracking(2.0)
            .foregroundStyle(color)
    }
}
