import SwiftUI

public struct BoltCornerNotch: View {
    let size: CGFloat
    let color: Color

    public init(size: CGFloat = 28, color: Color = .boltYellow) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Canvas { context, canvasSize in
            var path = Path()
            path.move(to: CGPoint(x: canvasSize.width, y: 0))
            path.addLine(to: CGPoint(x: canvasSize.width - size, y: 0))
            path.addLine(to: CGPoint(x: canvasSize.width, y: size))
            path.closeSubpath()

            context.fill(path, with: .color(color))
        }
    }
}

public extension View {
    func boltCornerNotch(size: CGFloat = 28, color: Color = .boltYellow) -> some View {
        overlay(
            BoltCornerNotch(size: size, color: color),
            alignment: .topTrailing
        )
    }
}
