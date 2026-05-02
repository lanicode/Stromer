import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    static let boltCream = Color(lightHex: 0xF4F1E8, darkHex: 0x07110F)
    static let boltCreamDeep = Color(lightHex: 0xE8E2D0, darkHex: 0x020706)
    static let boltPaper = Color(lightHex: 0xFBF8F0, darkHex: 0x101B1A)

    static let boltInk = Color(lightHex: 0x0E1817, darkHex: 0xF7F1E6)
    static let boltInkSoft = Color.boltInk.opacity(0.62)
    static let boltInkFaint = Color.boltInk.opacity(0.35)

    static let boltHair = Color.boltInk.opacity(0.12)
    static let boltHair2 = Color.boltInk.opacity(0.06)

    static let boltTeal = Color(lightHex: 0x0E6B64, darkHex: 0x59D5C7)
    static let boltTealDeep = Color(lightHex: 0x0A4F4A, darkHex: 0x8FE5D8)
    static let boltTealSoft = Color.boltTeal.opacity(0.10)

    static let boltYellow = Color(lightHex: 0xF6C445, darkHex: 0xF8D46B)
    static let boltYellowDeep = Color(lightHex: 0xD9A422, darkHex: 0xF0B637)

    static let boltOk = Color(lightHex: 0x2F8F45, darkHex: 0x62D67B)
    static let boltWarn = Color(lightHex: 0xC76A1F, darkHex: 0xF2A85A)
    static let boltBad = Color(lightHex: 0xB33A2A, darkHex: 0xFF7A68)

    static let boltInkFixed = Color(hex: 0x0E1817)
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(lightHex: UInt32, darkHex: UInt32) {
        #if canImport(UIKit)
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(hex: hex)
        })
        #else
        self.init(hex: lightHex)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
