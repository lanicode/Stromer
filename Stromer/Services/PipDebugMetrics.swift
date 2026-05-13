import Foundation
import Observation
import StromerScanner

@MainActor
@Observable
final class PipDebugMetrics {
    private nonisolated static let defaultReadsKey = "com.lanicode.StromerApp.pip-debug-reads"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let readsKey: String

    private(set) var readsTotal: Int

    init(
        defaults: UserDefaults = UserDefaults(suiteName: StromerIdentifiers.appGroup) ?? .standard,
        readsKey: String = PipDebugMetrics.defaultReadsKey
    ) {
        self.defaults = defaults
        self.readsKey = readsKey
        self.readsTotal = defaults.integer(forKey: readsKey)
    }

    func incrementReads() {
        readsTotal += 1
        defaults.set(readsTotal, forKey: readsKey)
    }

    func resetSession() {
        readsTotal = 0
        defaults.set(0, forKey: readsKey)
    }
}
