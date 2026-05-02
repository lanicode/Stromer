import SwiftUI

public struct BoltSLockup: View {
    let size: CGFloat

    public init(size: CGFloat = 28) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.boltTeal)

            Text("S")
                .font(.system(size: size * 0.75, weight: .heavy))
                .foregroundStyle(Color.boltCream)
                .tracking(-2)

            BoltGlyph(
                size: size * 0.45,
                fillColor: .boltYellow,
                strokeColor: .boltTeal,
                strokeWidth: max(1.0, size * 0.04)
            )
            .offset(x: size * 0.08, y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}
