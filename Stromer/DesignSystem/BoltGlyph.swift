import SwiftUI

public struct BoltGlyph: View {
    let size: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let strokeWidth: CGFloat

    public init(
        size: CGFloat = 14,
        fillColor: Color = .boltYellow,
        strokeColor: Color = .boltTeal,
        strokeWidth: CGFloat = 1.2
    ) {
        self.size = size
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 28
            let scaleY = canvasSize.height / 36

            var path = Path()
            let points: [(CGFloat, CGFloat)] = [
                (18, 2),
                (4, 20),
                (12, 20),
                (8, 34),
                (24, 14),
                (16, 14),
                (20, 2)
            ]

            for (index, point) in points.enumerated() {
                let cgPoint = CGPoint(
                    x: point.0 * scaleX,
                    y: point.1 * scaleY
                )
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
            path.closeSubpath()

            context.fill(path, with: .color(fillColor))
            context.stroke(
                path,
                with: .color(strokeColor),
                style: StrokeStyle(
                    lineWidth: strokeWidth,
                    lineJoin: .round
                )
            )
        }
        .frame(width: size, height: size * (36.0 / 28.0))
    }
}
