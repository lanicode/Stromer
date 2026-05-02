import Foundation
import XCTest

@MainActor
final class WidgetRefreshCoordinatorTests: XCTestCase {
    func testFirstReadingReloadsImmediately() {
        let now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)
    }

    func testSecondReadingWithinDebounceIsSuppressed() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 29)
        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)
    }

    func testReadingAfterDebounceReloads() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 31)
        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 2)
    }

    func testBackgroundReloadsImmediatelyInsideDebounceWindow() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 5)
        coordinator.requestReload(reason: .background)

        XCTAssertEqual(reloadCount, 2)
    }

    func testForegroundReloadsImmediatelyInsideDebounceWindow() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 5)
        coordinator.requestReload(reason: .foreground)

        XCTAssertEqual(reloadCount, 2)
    }

    func testDeviceLifecycleReloadsImmediatelyInsideDebounceWindow() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 }
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 5)
        coordinator.requestReload(reason: .deviceRegistered)
        now = Date(timeIntervalSince1970: 10)
        coordinator.requestReload(reason: .deviceDeleted)

        XCTAssertEqual(reloadCount, 3)
    }
}
