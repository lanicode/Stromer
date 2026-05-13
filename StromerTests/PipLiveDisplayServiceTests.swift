import Foundation
import XCTest

@MainActor
final class PipLiveDisplayServiceTests: XCTestCase {
    func testIsSupportedCanBeQueriedWithoutStartingPiP() throws {
        let metrics = PipDebugMetrics(defaults: try makeDefaults(), readsKey: "reads")
        let service = PipLiveDisplayService(metrics: metrics)

        _ = service.isSupported
    }

    func testStartReportsUnsupportedPiPAndStopIsIdempotent() throws {
        let metrics = PipDebugMetrics(defaults: try makeDefaults(), readsKey: "reads")
        let service = PipLiveDisplayService(
            metrics: metrics,
            supportProvider: { false }
        )

        service.start()

        XCTAssertFalse(service.isPipActive)
        XCTAssertEqual(service.lastError, "PiP nicht unterstützt.")

        service.stop()
        service.stop()
        XCTAssertFalse(service.isPipActive)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "com.lanicode.StromerApp.tests.pip-service"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw PipLiveDisplayServiceTestError.userDefaultsUnavailable
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private enum PipLiveDisplayServiceTestError: Error {
    case userDefaultsUnavailable
}
