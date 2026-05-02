import Foundation
import XCTest

final class OnboardingStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "stromer.onboarding.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultValueIsFalse() {
        let state = OnboardingState(defaults: defaults)

        XCTAssertFalse(state.hasCompletedOnboarding)
    }

    func testSettingCompletedPersistsTrue() {
        let state = OnboardingState(defaults: defaults)

        state.complete()

        XCTAssertTrue(defaults.bool(forKey: OnboardingState.defaultKey))
        XCTAssertTrue(state.hasCompletedOnboarding)
    }

    func testResetPersistsFalse() {
        defaults.set(true, forKey: OnboardingState.defaultKey)
        let state = OnboardingState(defaults: defaults)

        state.reset()

        XCTAssertFalse(defaults.bool(forKey: OnboardingState.defaultKey))
        XCTAssertFalse(state.hasCompletedOnboarding)
    }

    func testNewInstanceReadsPersistedValue() {
        let firstState = OnboardingState(defaults: defaults)
        firstState.complete()

        let secondState = OnboardingState(defaults: defaults)

        XCTAssertTrue(secondState.hasCompletedOnboarding)
    }

    func testReloadReadsExternalDefaultChange() {
        let state = OnboardingState(defaults: defaults)
        defaults.set(true, forKey: OnboardingState.defaultKey)

        state.reload()

        XCTAssertTrue(state.hasCompletedOnboarding)
    }
}
