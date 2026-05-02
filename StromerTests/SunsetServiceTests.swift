import XCTest

@MainActor
final class SunsetServiceTests: XCTestCase {
    func testSunsetInGreeceInMayIsPlausible() throws {
        let date = try makeUTCDate(year: 2026, month: 5, day: 15)
        let sunset = try XCTUnwrap(SunsetService.sunsetTime(
            for: date,
            latitude: 37.98,
            longitude: 23.72
        ))

        let localHour = localHour(sunset, timeZoneIdentifier: "Europe/Athens")

        XCTAssertGreaterThan(localHour, 20.0)
        XCTAssertLessThan(localHour, 20.8)
    }

    func testSunsetInBerlinAtEndOfMayIsPlausible() throws {
        let date = try makeUTCDate(year: 2026, month: 5, day: 31)
        let sunset = try XCTUnwrap(SunsetService.sunsetTime(
            for: date,
            latitude: 52.52,
            longitude: 13.405
        ))

        let localHour = localHour(sunset, timeZoneIdentifier: "Europe/Berlin")

        XCTAssertGreaterThan(localHour, 21.0)
        XCTAssertLessThan(localHour, 21.6)
    }

    func testPolarDayOrNightReturnsNil() throws {
        let summer = try makeUTCDate(year: 2026, month: 6, day: 21)
        let winter = try makeUTCDate(year: 2026, month: 12, day: 21)

        XCTAssertNil(SunsetService.sunsetTime(
            for: summer,
            latitude: 78.22,
            longitude: 15.65
        ))
        XCTAssertNil(SunsetService.sunsetTime(
            for: winter,
            latitude: 78.22,
            longitude: 15.65
        ))
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
}
