import CoreLocation
import Foundation

struct LocalHorizonTimes: Equatable {
    let astronomicalSunrise: Date?
    let astronomicalSunset: Date?
    let localSunrise: Date?
    let localSunset: Date?

    var sunsetDifferenceMinutes: Int? {
        guard let astronomicalSunset, let localSunset else {
            return nil
        }

        return Int(astronomicalSunset.timeIntervalSince(localSunset) / 60)
    }

    var sunriseDifferenceMinutes: Int? {
        guard let astronomicalSunrise, let localSunrise else {
            return nil
        }

        return Int(localSunrise.timeIntervalSince(astronomicalSunrise) / 60)
    }
}

enum LocalHorizonCalculator {
    static func compute(
        for coordinate: CLLocationCoordinate2D,
        date: Date,
        horizon: ElevationService.HorizonProfile
    ) -> LocalHorizonTimes {
        let sunTimes = AstronomicalCalculator.sunTimes(for: date, coordinate: coordinate)
        let dayStart = Calendar(identifier: .gregorian).startOfDay(for: date)

        return LocalHorizonTimes(
            astronomicalSunrise: sunTimes.sunrise,
            astronomicalSunset: sunTimes.sunset,
            localSunrise: findLocalCrossing(
                coordinate: coordinate,
                horizon: horizon,
                dayStart: dayStart,
                searchingRise: true
            ),
            localSunset: findLocalCrossing(
                coordinate: coordinate,
                horizon: horizon,
                dayStart: dayStart,
                searchingRise: false
            )
        )
    }

    private static func findLocalCrossing(
        coordinate: CLLocationCoordinate2D,
        horizon: ElevationService.HorizonProfile,
        dayStart: Date,
        searchingRise: Bool
    ) -> Date? {
        var previousAboveHorizon: Bool?

        for minute in stride(from: 0, to: 24 * 60, by: 2) {
            let time = dayStart.addingTimeInterval(Double(minute) * 60)
            let position = AstronomicalCalculator.sunPosition(at: time, coordinate: coordinate)
            let localHorizon = horizon.horizonAngle(at: position.azimuthDegreesFromNorth)
            let isAboveHorizon = position.altitudeDegrees > localHorizon

            if let previousAboveHorizon {
                if searchingRise, !previousAboveHorizon, isAboveHorizon {
                    return time
                }
                if !searchingRise, previousAboveHorizon, !isAboveHorizon {
                    return time
                }
            }

            previousAboveHorizon = isAboveHorizon
        }

        return nil
    }
}
