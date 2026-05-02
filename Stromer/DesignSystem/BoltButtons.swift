import SwiftUI

public struct BoltPrimary: View {
    let title: String
    let showsBolt: Bool
    let action: () -> Void

    public init(
        _ title: String,
        showsBolt: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.showsBolt = showsBolt
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsBolt {
                    BoltGlyph(
                        size: 14,
                        fillColor: .boltYellow,
                        strokeColor: .boltCream
                    )
                }
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(2.0)
                    .foregroundStyle(Color.boltCream)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.boltTeal)
        }
        .buttonStyle(.plain)
    }
}

public struct BoltSecondary: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Color.boltInk)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .overlay(
                    Rectangle().stroke(Color.boltHair, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
