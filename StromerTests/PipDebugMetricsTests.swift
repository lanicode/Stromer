import Foundation
import XCTest

@MainActor
final class PipDebugMetricsTests: XCTestCase {
    func testIncrementReadsPersistsValue() throws {
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let metrics = PipDebugMetrics(defaults: defaults, readsKey: "reads")

        metrics.incrementReads()
        metrics.incrementReads()

        XCTAssertEqual(metrics.readsTotal, 2)
        XCTAssertEqual(defaults.integer(forKey: "reads"), 2)
    }

    func testResetSessionSetsReadsToZero() throws {
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults.set(7, forKey: "reads")
        let metrics = PipDebugMetrics(defaults: defaults, readsKey: "reads")

        metrics.resetSession()

        XCTAssertEqual(metrics.readsTotal, 0)
        XCTAssertEqual(defaults.integer(forKey: "reads"), 0)
    }

    private var defaultsSuiteName: String {
        "com.lanicode.StromerApp.tests.pip-debug"
    }

    private func makeDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: defaultsSuiteName) else {
            throw TestError.userDefaultsUnavailable
        }
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }
}

private enum TestError: Error {
    case userDefaultsUnavailable
}
