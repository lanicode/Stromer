import Foundation
import XCTest

@MainActor
final class ReceptionStatusObserverTests: XCTestCase {
    func testStatusIsLiveForRecentReading() {
        let now = Date(timeIntervalSince1970: 1_000)
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(at: now.addingTimeInterval(-29))

        XCTAssertEqual(observer.status, .live)
    }

    func testStatusIsWaitingForReadingInsideGraceWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(at: now.addingTimeInterval(-90))

        XCTAssertEqual(observer.status, .waiting)
    }

    func testStatusIsOfflineForOldReading() {
        let now = Date(timeIntervalSince1970: 1_000)
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(at: now.addingTimeInterval(-301))

        XCTAssertEqual(observer.status, .offline)
    }

    func testStatusIsWaitingWithoutReading() {
        let observer = ReceptionStatusObserver()

        observer.recompute()

        XCTAssertEqual(observer.status, .waiting)
    }
}
