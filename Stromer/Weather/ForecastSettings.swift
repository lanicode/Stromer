import Foundation
import Observation

@Observable
final class ForecastSettings {
    var isForecastEnabled: Bool {
        didSet { save() }
    }

    var usesTopography: Bool {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let isForecastEnabled = "stromer.forecast.enabled"
        static let usesTopography = "stromer.forecast.usesTopography"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isForecastEnabled = defaults.object(forKey: Key.isForecastEnabled) as? Bool ?? true
        self.usesTopography = defaults.object(forKey: Key.usesTopography) as? Bool ?? true
    }

    func save() {
        defaults.set(isForecastEnabled, forKey: Key.isForecastEnabled)
        defaults.set(usesTopography, forKey: Key.usesTopography)
    }
}
