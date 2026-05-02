import SwiftUI

public extension Color {
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
    static let boltTealSoft = Color.boltTeal.opacity(0.10)

    static let boltYellow = Color(hex: 0xF6C445)
    static let boltYellowDeep = Color(hex: 0xD9A422)

    static let boltOk = Color(hex: 0x2F8F45)
    static let boltWarn = Color(hex: 0xC76A1F)
    static let boltBad = Color(hex: 0xB33A2A)
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
