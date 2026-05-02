import StromerScanner
import SwiftUI

extension Color {
    static let boltCream = Color(hex: 0xF4F1E8)
    static let boltCreamDeep = Color(hex: 0xE8E2D0)
    static let boltPaper = Color(hex: 0xFBF8F0)
    static let boltInk = Color(hex: 0x0E1817)
    static let boltInkSoft = Color.boltInk.opacity(0.62)
    static let boltInkFaint = Color.boltInk.opacity(0.35)
    static let boltHair = Color.boltInk.opacity(0.12)
    static let boltHair2 = Color.boltInk.opacity(0.06)
    static let boltTeal = Color(hex: 0x0E6B64)
    static let boltTealDeep = Color(hex: 0x0A4F4A)
    static let boltYellow = Color(hex: 0xF6C445)
    static let boltOk = Color(hex: 0x2F8F45)
    static let boltWarn = Color(hex: 0xC76A1F)
    static let boltBad = Color(hex: 0xB33A2A)

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct BoltWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.boltCream, .boltCreamDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct BoltWidgetGlyph: View {
    let size: CGFloat
    var fillColor: Color = .boltYellow
    var strokeColor: Color = .boltTeal
    var strokeWidth: CGFloat = 1.2

    var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 28
            let scaleY = canvasSize.height / 36
            let points: [(CGFloat, CGFloat)] = [
                (18, 2), (4, 20), (12, 20), (8, 34),
                (24, 14), (16, 14), (20, 2)
            ]

            var path = Path()
            for (index, point) in points.enumerated() {
                let cgPoint = CGPoint(x: point.0 * scaleX, y: point.1 * scaleY)
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
                style: StrokeStyle(lineWidth: strokeWidth, lineJoin: .round)
            )
        }
        .frame(width: size, height: size * (36.0 / 28.0))
    }
}

struct BoltWidgetSLockup: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.boltTeal)

            Text("S")
                .font(.system(size: size * 0.75, weight: .heavy))
                .foregroundStyle(Color.boltCream)

            BoltWidgetGlyph(
                size: size * 0.45,
                fillColor: .boltYellow,
                strokeColor: .boltTeal,
                strokeWidth: max(1, size * 0.04)
            )
            .offset(x: size * 0.08, y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

struct BoltWidgetCornerNotch: View {
    let size: CGFloat
    var color: Color = .boltYellow

    var body: some View {
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

extension View {
    func boltWidgetCornerNotch(size: CGFloat = 20, color: Color = .boltYellow) -> some View {
        overlay(BoltWidgetCornerNotch(size: size, color: color), alignment: .topTrailing)
    }
}

struct BoltWidgetSpark: View {
    let values: [Double]
    var color: Color = .boltYellow
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 0.0001)
            var path = Path()

            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let y = size.height - (CGFloat((value - minValue) / range) * size.height)
                let point = CGPoint(x: x, y: y)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .square, lineJoin: .miter)
            )
        }
    }
}

enum BoltWidgetDeviceKind {
    case battery
    case solar
    case dcDc
    case other

    init(icon: String, title: String) {
        let text = "\(icon) \(title)".lowercased()
        if text.contains("sun") || text.contains("solar") {
            self = .solar
        } else if text.contains("arrow.left.arrow.right") || text.contains("orion") || text.contains("dc") {
            self = .dcDc
        } else if text.contains("battery") || text.contains("shunt") || text.contains("bmv") {
            self = .battery
        } else {
            self = .other
        }
    }

    var tileColor: Color {
        switch self {
        case .battery, .dcDc:
            return .boltTeal
        case .solar:
            return .boltYellow
        case .other:
            return .boltHair2
        }
    }

    var iconColor: Color {
        switch self {
        case .solar:
            return .boltInk
        case .battery, .dcDc:
            return .boltCream
        case .other:
            return .boltInkSoft
        }
    }

    var shortLabel: String {
        switch self {
        case .battery:
            return "HAUS"
        case .solar:
            return "SOLAR"
        case .dcDc:
            return "DCDC"
        case .other:
            return "LIVE"
        }
    }
}

extension StromerWidgetDeviceSnapshot {
    var boltKind: BoltWidgetDeviceKind {
        BoltWidgetDeviceKind(icon: deviceTypeIcon, title: deviceTypeTitle)
    }

    var numericMainValue: Double? {
        Double(mainValue.replacingOccurrences(of: ",", with: "."))
    }
}

extension DeviceFreshness {
    var boltWidgetColor: Color {
        switch self {
        case .fresh:
            return .boltOk
        case .delayed:
            return .boltWarn
        case .stale, .missing:
            return .boltBad
        }
    }
}
