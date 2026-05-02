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
}
