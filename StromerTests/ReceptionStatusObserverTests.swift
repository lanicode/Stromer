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

    func testPerDeviceStatusIsLiveForRecentReading() {
        let now = Date(timeIntervalSince1970: 1_000)
        let deviceID = UUID()
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(makeBatteryReading(deviceID: deviceID, timestamp: now.addingTimeInterval(-20)))

        XCTAssertEqual(observer.status(for: deviceID), .live)
    }

    func testPerDeviceStatusIsStaleForThirtyMinuteOldReading() {
        let now = Date(timeIntervalSince1970: 4_000)
        let deviceID = UUID()
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(makeBatteryReading(deviceID: deviceID, timestamp: now.addingTimeInterval(-30 * 60)))

        XCTAssertEqual(observer.status(for: deviceID), .stale)
    }

    func testPerDeviceStatusIsOfflineAfterOneHour() {
        let now = Date(timeIntervalSince1970: 8_000)
        let deviceID = UUID()
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(makeBatteryReading(deviceID: deviceID, timestamp: now.addingTimeInterval(-3_601)))

        XCTAssertEqual(observer.status(for: deviceID), .offline)
    }

    func testRelativeTimeTextUsesDeviceLastSeen() {
        let now = Date(timeIntervalSince1970: 8_000)
        let deviceID = UUID()
        let observer = ReceptionStatusObserver(nowProvider: { now })

        observer.handleReading(makeBatteryReading(deviceID: deviceID, timestamp: now.addingTimeInterval(-125)))

        XCTAssertEqual(observer.relativeTimeText(for: deviceID), "vor 2 Min")
    }
}
