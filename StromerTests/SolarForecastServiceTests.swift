import Foundation
import XCTest

@MainActor
final class SolarForecastServiceTests: XCTestCase {
    func testURLConstructionIncludesSolarFields() throws {
        let url = try XCTUnwrap(SolarForecastService.makeURL(
            latitude: 37.98,
            longitude: 23.72,
            forecastDays: 7
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(items["latitude"], "37.98")
        XCTAssertEqual(items["longitude"], "23.72")
        XCTAssertEqual(items["forecast_days"], "7")
        XCTAssertTrue(items["hourly"]?.contains("shortwave_radiation") == true)
        XCTAssertTrue(items["hourly"]?.contains("direct_normal_irradiance") == true)
        XCTAssertTrue(items["daily"]?.contains("shortwave_radiation_sum") == true)
    }

    func testDecodesSolarForecastResponse() async throws {
        let data = Self.sampleJSON()
        let service = SolarForecastService(dataLoader: { url in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        })

        let response = try await service.fetchSolarForecast(
            latitude: 37.98,
            longitude: 23.72,
            forecastDays: 7
        )

        XCTAssertEqual(response.timezone, "Europe/Athens")
        XCTAssertEqual(response.hourly.shortwave_radiation.first ?? nil, 0)
        XCTAssertEqual(response.daily.shortwave_radiation_sum.first ?? nil, 18.2)
    }

    func testCachingUsesCachedResponseWithinLifetime() async throws {
        let counter = ForecastRequestCounter()
        let data = Self.sampleJSON()
        let service = SolarForecastService(
            cacheLifetime: 3_600,
            nowProvider: { Date(timeIntervalSince1970: 1_000) },
            dataLoader: { url in
                await counter.increment()
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (data, response)
            }
        )

        _ = try await service.fetchSolarForecast(latitude: 37.98, longitude: 23.72, forecastDays: 7)
        _ = try await service.fetchSolarForecast(latitude: 37.98, longitude: 23.72, forecastDays: 7)

        let count = await counter.value()
        XCTAssertEqual(count, 1)
    }

    private static func sampleJSON() -> Data {
        Data(
            """
            {
              "latitude": 37.98,
              "longitude": 23.72,
              "timezone": "Europe/Athens",
              "hourly": {
                "time": ["2026-05-03T00:00", "2026-05-03T01:00"],
                "shortwave_radiation": [0, 120],
                "direct_radiation": [0, 80],
                "diffuse_radiation": [0, 40],
                "direct_normal_irradiance": [0, 160],
                "cloud_cover": [20, 30],
                "is_day": [0, 1],
                "weather_code": [0, 1],
                "temperature_2m": [18.2, 19.1]
              },
              "daily": {
                "time": ["2026-05-03"],
                "shortwave_radiation_sum": [18.2],
                "sunrise": ["2026-05-03T06:20"],
                "sunset": ["2026-05-03T20:15"],
                "weather_code": [1]
              }
            }
            """.utf8
        )
    }
}

private actor ForecastRequestCounter {
    private var count = 0

    func value() -> Int {
        count
    }

    func increment() {
        count += 1
    }
}
