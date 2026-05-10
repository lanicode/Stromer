import Foundation
import XCTest

@MainActor
final class WidgetRefreshCoordinatorTests: XCTestCase {
    func testFirstReadingReloadsImmediately() {
        let now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 30
        )

        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)
    }

    func testSecondReadingWithinDebounceIsDeferred() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 30
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 29)
        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)
    }

    func testReadingInsideDebounceSchedulesTrailingReload() async {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 30
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 29.99)
        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)

        try? await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(reloadCount, 2)
    }

    func testReadingDebounceUsesInjectedInterval() async {
        let now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 5
        )

        coordinator.requestReload(reason: .reading)
        coordinator.requestReload(reason: .reading)

        XCTAssertEqual(reloadCount, 1)

        try? await Task.sleep(for: .milliseconds(1_000))
        XCTAssertEqual(reloadCount, 1)

        try? await Task.sleep(for: .milliseconds(4_500))
        XCTAssertEqual(reloadCount, 2)
    }

    func testReadingAfterDebounceReloads() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 30
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

    func testSemanticReloadReasonsBypassReadingDebounce() {
        var now = Date(timeIntervalSince1970: 0)
        var reloadCount = 0
        let coordinator = WidgetRefreshCoordinator(
            nowProvider: { now },
            reloadHandler: { reloadCount += 1 },
            readingDebounceInterval: 86_400
        )

        coordinator.requestReload(reason: .reading)
        now = Date(timeIntervalSince1970: 1)
        coordinator.requestReload(reason: .foreground)
        now = Date(timeIntervalSince1970: 2)
        coordinator.requestReload(reason: .background)
        now = Date(timeIntervalSince1970: 3)
        coordinator.requestReload(reason: .deviceRegistered)
        now = Date(timeIntervalSince1970: 4)
        coordinator.requestReload(reason: .deviceDeleted)

        XCTAssertEqual(reloadCount, 5)
    }
}
