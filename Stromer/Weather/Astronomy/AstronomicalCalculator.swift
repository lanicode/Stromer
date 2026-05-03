import CoreLocation
import Foundation

/// Offline astronomy helpers adapted from Brise's SunCalc-style calculator.
enum AstronomicalCalculator {
    private static let dayMs: Double = 1000 * 60 * 60 * 24
    private static let j1970: Double = 2_440_588
    private static let j2000: Double = 2_451_545
    private static let rad: Double = .pi / 180
    private static let e: Double = rad * 23.4397

    struct SunPosition {
        let azimuth: Double
        let altitude: Double

        var azimuthDegreesFromNorth: Double {
            let degrees = azimuth * 180 / .pi + 180
            return degrees.truncatingRemainder(dividingBy: 360)
        }

        var altitudeDegrees: Double {
            altitude * 180 / .pi
        }
    }

    struct SunTimes {
        let sunrise: Date?
        let sunset: Date?
        let solarNoon: Date?
    }

    static func sunPosition(at date: Date, coordinate: CLLocationCoordinate2D) -> SunPosition {
        let lw = rad * -coordinate.longitude
        let phi = rad * coordinate.latitude
        let d = toDays(date)
        let c = sunCoords(d)
        let h = siderealTime(d, lw) - c.ra

        return SunPosition(
            azimuth: azimuth(h, phi, c.dec),
            altitude: altitude(h, phi, c.dec)
        )
    }

    static func sunTimes(for date: Date, coordinate: CLLocationCoordinate2D) -> SunTimes {
        let lw = rad * -coordinate.longitude
        let phi = rad * coordinate.latitude
        let d = toDays(date)
        let n = julianCycle(d, lw)
        let ds = approxTransit(0, lw, n)
        let m = solarMeanAnomaly(ds)
        let l = eclipticLongitude(m)
        let dec = declination(l, 0)
        let noon = solarTransitJ(ds, m, l)

        func time(angle: Double, rising: Bool) -> Date? {
            guard let set = getSetJ(angle * rad, lw, phi, dec, n, m, l) else {
                return nil
            }

            let j = rising ? noon - (set - noon) : set
            return fromJulian(j)
        }

        return SunTimes(
            sunrise: time(angle: -0.833, rising: true),
            sunset: time(angle: -0.833, rising: false),
            solarNoon: fromJulian(noon)
        )
    }

    private static func toJulian(_ date: Date) -> Double {
        date.timeIntervalSince1970 * 1000 / dayMs - 0.5 + j1970
    }

    private static func fromJulian(_ j: Double) -> Date {
        Date(timeIntervalSince1970: (j + 0.5 - j1970) * dayMs / 1000)
    }

    private static func toDays(_ date: Date) -> Double {
        toJulian(date) - j2000
    }

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
    }

    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
    }

    private static func azimuth(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
    }

    private static func altitude(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
    }

    private static func siderealTime(_ d: Double, _ lw: Double) -> Double {
        rad * (280.16 + 360.9856235 * d) - lw
    }

    private static func solarMeanAnomaly(_ d: Double) -> Double {
        rad * (357.5291 + 0.98560028 * d)
    }

    private static func eclipticLongitude(_ m: Double) -> Double {
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let p = rad * 102.9372
        return m + c + p + .pi
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let m = solarMeanAnomaly(d)
        let l = eclipticLongitude(m)
        return (declination(l, 0), rightAscension(l, 0))
    }

    private static func julianCycle(_ d: Double, _ lw: Double) -> Double {
        (d - 0.0009 - lw / (2 * .pi)).rounded()
    }

    private static func approxTransit(_ ht: Double, _ lw: Double, _ n: Double) -> Double {
        0.0009 + (ht + lw) / (2 * .pi) + n
    }

    private static func solarTransitJ(_ ds: Double, _ m: Double, _ l: Double) -> Double {
        j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
    }

    private static func hourAngle(_ h: Double, _ phi: Double, _ d: Double) -> Double? {
        let value = (sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d))
        guard value >= -1, value <= 1 else {
            return nil
        }

        return acos(value)
    }

    private static func getSetJ(
        _ h: Double,
        _ lw: Double,
        _ phi: Double,
        _ dec: Double,
        _ n: Double,
        _ m: Double,
        _ l: Double
    ) -> Double? {
        guard let w = hourAngle(h, phi, dec) else {
            return nil
        }

        let a = approxTransit(w, lw, n)
        return solarTransitJ(a, m, l)
    }
}
