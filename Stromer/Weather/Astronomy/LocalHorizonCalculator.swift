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

extension ElevationService.HorizonProfile {
    var dominantDirection: String {
        guard let highest = highestSample else {
            return ""
        }
        return directionName(for: highest.azimuth)
    }

    var dominantObstacleType: String {
        guard let highest = highestSample else {
            return "Gelände"
        }

        switch highest.horizonAngle {
        case 8...:
            return "Berge"
        case 3..<8:
            return "Hügel"
        default:
            return "Gelände"
        }
    }

    private var highestSample: HorizonSample? {
        samples.max { $0.horizonAngle < $1.horizonAngle }
    }

    private func directionName(for azimuth: Double) -> String {
        let normalized = azimuth.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized

        switch positive {
        case 337.5..<360, 0..<22.5:
            return "Norden"
        case 22.5..<67.5:
            return "Nordosten"
        case 67.5..<112.5:
            return "Osten"
        case 112.5..<157.5:
            return "Südosten"
        case 157.5..<202.5:
            return "Süden"
        case 202.5..<247.5:
            return "Südwesten"
        case 247.5..<292.5:
            return "Westen"
        case 292.5..<337.5:
            return "Nordwesten"
        default:
            return ""
        }
    }
}
