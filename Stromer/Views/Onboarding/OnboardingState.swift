import Foundation
import Observation

@Observable
final class OnboardingState {
    static let defaultKey = "stromer.onboarding.hasCompleted"

    private let defaults: UserDefaults
    private let key: String

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: key)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        key: String = OnboardingState.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
        self.hasCompletedOnboarding = defaults.bool(forKey: key)
    }

    func complete() {
        hasCompletedOnboarding = true
    }

    func reset() {
        hasCompletedOnboarding = false
    }

    func reload() {
        hasCompletedOnboarding = defaults.bool(forKey: key)
    }
}
