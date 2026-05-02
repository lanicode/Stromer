import SwiftUI
import UIKit
import XCTest

@MainActor
final class DesignSystemTests: XCTestCase {
    func testBoltColorTokensResolveToUIColor() {
        let colors: [Color] = [
            .boltCream,
            .boltCreamDeep,
            .boltPaper,
            .boltInk,
            .boltInkSoft,
            .boltInkFaint,
            .boltHair,
            .boltHair2,
            .boltTeal,
            .boltTealDeep,
            .boltTealSoft,
            .boltYellow,
            .boltYellowDeep,
            .boltOk,
            .boltWarn,
            .boltBad
        ]

        for color in colors {
            XCTAssertNotNil(UIColor(color))
        }
    }

    func testBoltCoreTokensResolveDifferentlyInDarkMode() {
        let traits = (
            light: UITraitCollection(userInterfaceStyle: .light),
            dark: UITraitCollection(userInterfaceStyle: .dark)
        )

        XCTAssertNotEqual(
            resolvedRGB(.boltCream, traits.light),
            resolvedRGB(.boltCream, traits.dark)
        )
        XCTAssertNotEqual(
            resolvedRGB(.boltPaper, traits.light),
            resolvedRGB(.boltPaper, traits.dark)
        )
        XCTAssertNotEqual(
            resolvedRGB(.boltInk, traits.light),
            resolvedRGB(.boltInk, traits.dark)
        )
    }

    func testBoltTextContrastIsReadableInLightAndDarkMode() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground: .boltInk, background: .boltCream, traits: traits),
                7.0
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground: .boltInk, background: .boltPaper, traits: traits),
                7.0
            )
        }
    }

    func testFixedInkStaysReadableOnYellowInLightAndDarkMode() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground: .boltInkFixed, background: .boltYellow, traits: traits),
                7.0
            )
        }
    }

    func testBoltGlyphRendersForDifferentSizes() {
        assertViewRenders(BoltGlyph(size: 8))
        assertViewRenders(BoltGlyph(size: 28))
        assertViewRenders(BoltGlyph(size: 72))
    }

    func testBoltSLockupRendersForDifferentSizes() {
        assertViewRenders(BoltSLockup(size: 18))
        assertViewRenders(BoltSLockup(size: 44))
        assertViewRenders(BoltSLockup(size: 96))
    }

    func testBoltSparkRendersEmptyValuesWithoutCrash() {
        assertViewRenders(BoltSpark(values: []))
    }

    func testBoltCornerNotchRendersWithoutCrash() {
        assertViewRenders(
            Color.boltPaper
                .frame(width: 96, height: 96)
                .boltCornerNotch()
        )
    }

    private func assertViewRenders<V: View>(
        _ view: V,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 160, height: 160)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, file: file, line: line)
    }

    private func resolvedRGB(_ color: Color, _ traits: UITraitCollection) -> [CGFloat] {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { ($0 * 1_000).rounded() / 1_000 }
    }

    private func contrastRatio(
        foreground: Color,
        background: Color,
        traits: UITraitCollection
    ) -> CGFloat {
        let foregroundLuminance = relativeLuminance(UIColor(foreground).resolvedColor(with: traits))
        let backgroundLuminance = relativeLuminance(UIColor(background).resolvedColor(with: traits))
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func component(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * component(red)
            + 0.7152 * component(green)
            + 0.0722 * component(blue)
    }
}
