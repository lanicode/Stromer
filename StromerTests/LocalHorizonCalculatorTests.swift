import CoreLocation
import XCTest

@MainActor
final class LocalHorizonCalculatorTests: XCTestCase {
    func testLocalSunsetInGreeceInMayIsPlausibleWithFlatHorizon() throws {
        let date = try makeUTCDate(year: 2026, month: 5, day: 15)
        let coordinate = CLLocationCoordinate2D(latitude: 37.98, longitude: 23.72)
        let times = LocalHorizonCalculator.compute(
            for: coordinate,
            date: date,
            horizon: horizonProfile(angle: 0)
        )
        let sunset = try XCTUnwrap(times.localSunset)
        let localHour = localHour(sunset, timeZoneIdentifier: "Europe/Athens")

        XCTAssertGreaterThan(localHour, 20.0)
        XCTAssertLessThan(localHour, 20.9)
    }

    func testLocalSunsetInBerlinInMayIsPlausibleWithFlatHorizon() throws {
        let date = try makeUTCDate(year: 2026, month: 5, day: 31)
        let coordinate = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        let times = LocalHorizonCalculator.compute(
            for: coordinate,
            date: date,
            horizon: horizonProfile(angle: 0)
        )
        let sunset = try XCTUnwrap(times.localSunset)
        let localHour = localHour(sunset, timeZoneIdentifier: "Europe/Berlin")

        XCTAssertGreaterThan(localHour, 21.0)
        XCTAssertLessThan(localHour, 21.8)
    }

    func testHighLocalHorizonMakesSunsetEarlier() throws {
        let date = try makeUTCDate(year: 2026, month: 5, day: 15)
        let coordinate = CLLocationCoordinate2D(latitude: 37.98, longitude: 23.72)
        let flat = LocalHorizonCalculator.compute(
            for: coordinate,
            date: date,
            horizon: horizonProfile(angle: 0)
        )
        let high = LocalHorizonCalculator.compute(
            for: coordinate,
            date: date,
            horizon: horizonProfile(angle: 8)
        )

        let flatSunset = try XCTUnwrap(flat.localSunset)
        let highSunset = try XCTUnwrap(high.localSunset)

        XCTAssertLessThan(highSunset, flatSunset)
    }

    func testDominantDirectionUsesHighestSample() {
        let profile = horizonProfile(
            highestAzimuth: 270,
            highestAngle: 12,
            baseAngle: 1
        )

        XCTAssertEqual(profile.dominantDirection, "Westen")
    }

    func testDominantObstacleTypeUsesHighestAngle() {
        XCTAssertEqual(horizonProfile(highestAzimuth: 270, highestAngle: 12).dominantObstacleType, "Berge")
        XCTAssertEqual(horizonProfile(highestAzimuth: 180, highestAngle: 5).dominantObstacleType, "Hügel")
        XCTAssertEqual(horizonProfile(highestAzimuth: 90, highestAngle: 2).dominantObstacleType, "Gelände")
    }

    private func makeUTCDate(year: Int, month: Int, day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
        return try XCTUnwrap(date)
    }

    private func localHour(_ date: Date, timeZoneIdentifier: String) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }

    private func horizonProfile(angle: Double) -> ElevationService.HorizonProfile {
        ElevationService.HorizonProfile(
            observerElevation: 0,
            observerEyeHeight: 1.7,
            samples: (0..<36).map {
                ElevationService.HorizonProfile.HorizonSample(
                    azimuth: Double($0) * 10,
                    terrainElevation: 0,
                    horizonAngle: angle
                )
            },
            sampleDistanceKm: 5,
            fetchedAt: Date()
        )
    }

    private func horizonProfile(
        highestAzimuth: Double,
        highestAngle: Double,
        baseAngle: Double = 0
    ) -> ElevationService.HorizonProfile {
        ElevationService.HorizonProfile(
            observerElevation: 0,
            observerEyeHeight: 1.7,
            samples: (0..<36).map {
                let azimuth = Double($0) * 10
                return ElevationService.HorizonProfile.HorizonSample(
                    azimuth: azimuth,
                    terrainElevation: 0,
                    horizonAngle: abs(azimuth - highestAzimuth) < 0.0001 ? highestAngle : baseAngle
                )
            },
            sampleDistanceKm: 5,
            fetchedAt: Date()
        )
    }
}
