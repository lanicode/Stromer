import Foundation
@testable import StromerScanner
import XCTest

final class FreshnessTests: XCTestCase {
    func testFreshnessThresholds() {
        let now = Date(timeIntervalSince1970: 100_000)

        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-119), now: now), .fresh)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-120), now: now), .delayed)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-121), now: now), .delayed)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-599), now: now), .delayed)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-600), now: now), .stale)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-601), now: now), .stale)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-86_400), now: now), .stale)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: now.addingTimeInterval(-86_401), now: now), .missing)
        XCTAssertEqual(DeviceFreshness(lastSeenAt: nil, now: now), .missing)
    }
}
