import SwiftUI

public struct BoltSpark: View {
    let values: [Double]
    let color: Color
    let lineWidth: CGFloat

    public init(
        values: [Double],
        color: Color = .boltTeal,
        lineWidth: CGFloat = 1.5
    ) {
        self.values = values
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                guard values.count > 1 else {
                    return
                }

                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = max(maxValue - minValue, 0.0001)

                var path = Path()
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                    let y = size.height - (CGFloat((value - minValue) / range) * size.height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .square,
                        lineJoin: .miter
                    )
                )
            }
        }
    }
}
