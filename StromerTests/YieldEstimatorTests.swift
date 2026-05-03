import Foundation
import SwiftData
import XCTest

@MainActor
final class YieldEstimatorTests: XCTestCase {
    func testCalculateEfficiencyFactorRequiresEnoughSolarDays() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        try insertSolarDays(
            count: 4,
            deviceID: deviceID,
            yieldWh: 1_500,
            into: store
        )
        let estimator = YieldEstimator(
            historyStore: store,
            solarService: MockSolarForecastProvider(response: Self.sampleForecast())
        )

        let factor = await estimator.calculateEfficiencyFactor(deviceID: deviceID)

        XCTAssertNil(factor)
    }

    func testCalculateEfficiencyFactorUsesMeasuredYield() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        try insertSolarDays(
            count: 7,
            deviceID: deviceID,
            yieldWh: 1_600,
            into: store
        )
        let estimator = YieldEstimator(
            historyStore: store,
            solarService: MockSolarForecastProvider(response: Self.sampleForecast())
        )

        let maybeFactor = await estimator.calculateEfficiencyFactor(deviceID: deviceID)
        let factor = try XCTUnwrap(maybeFactor)

        XCTAssertEqual(factor.avgYieldWh, 1_600, accuracy: 0.001)
        XCTAssertEqual(factor.maxYieldWh, 1_600, accuracy: 0.001)
        XCTAssertEqual(factor.sampleDays, 7)
        XCTAssertEqual(factor.confidence, 0.5, accuracy: 0.001)
    }

    func testConfidenceIncreasesWithMoreSampleDays() async throws {
        let sparseStore = try makeHistoryStore()
        let richStore = try makeHistoryStore()
        let deviceID = UUID()
        try insertSolarDays(count: 5, deviceID: deviceID, yieldWh: 1_200, into: sparseStore)
        try insertSolarDays(count: 14, deviceID: deviceID, yieldWh: 1_200, into: richStore)
        let forecast = MockSolarForecastProvider(response: Self.sampleForecast())

        let sparse = await YieldEstimator(
            historyStore: sparseStore,
            solarService: forecast
        ).calculateEfficiencyFactor(deviceID: deviceID)
        let rich = await YieldEstimator(
            historyStore: richStore,
            solarService: forecast
        ).calculateEfficiencyFactor(deviceID: deviceID)

        XCTAssertLessThan(try XCTUnwrap(sparse).confidence, try XCTUnwrap(rich).confidence)
        XCTAssertEqual(rich?.confidence, 1)
    }

    func testEstimateYieldUsesForecastRadiationAndEfficiency() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        try insertSolarDays(count: 7, deviceID: deviceID, yieldWh: 1_600, into: store)
        let estimator = YieldEstimator(
            historyStore: store,
            solarService: MockSolarForecastProvider(response: Self.sampleForecast(radiationMJ: 18))
        )

        let estimate = try await estimator.estimateYield(
            deviceID: deviceID,
            forDate: Date(),
            latitude: 37.98,
            longitude: 23.72,
            horizonProfile: nil
        )

        XCTAssertEqual(estimate.expectedWh ?? 0, 1_800, accuracy: 0.001)
        XCTAssertEqual(estimate.horizonLossPercent, 0, accuracy: 0.001)
    }

    func testEstimateYieldAppliesHorizonLoss() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        try insertSolarDays(count: 7, deviceID: deviceID, yieldWh: 1_600, into: store)
        let estimator = YieldEstimator(
            historyStore: store,
            solarService: MockSolarForecastProvider(response: Self.sampleForecast(radiationMJ: 18))
        )

        let estimate = try await estimator.estimateYield(
            deviceID: deviceID,
            forDate: Date(),
            latitude: 37.98,
            longitude: 23.72,
            horizonProfile: Self.horizonProfile(angle: 89)
        )

        XCTAssertGreaterThan(estimate.horizonLossPercent, 90)
        XCTAssertLessThan(estimate.expectedWh ?? 1, 200)
    }

    private func insertSolarDays(
        count: Int,
        deviceID: UUID,
        yieldWh: Double,
        into store: SwiftDataHistoryStore
    ) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<count {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let aggregate = DailyAggregate(
                deviceID: deviceID,
                dayStart: day,
                familyKind: "solar"
            )
            aggregate.yieldTodayMax = yieldWh
            store.context.insert(aggregate)
        }
        try store.context.save()
    }

    static func sampleForecast(radiationMJ: Double = 18) -> SolarForecastResponse {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let hourlyTimes = (0..<24).compactMap {
            calendar.date(byAdding: .hour, value: $0, to: start)
        }.map {
            SolarForecastResponse.hourFormatter.string(from: $0)
        }
        let dailyTimes = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }.map {
            SolarForecastResponse.dayFormatter.string(from: $0)
        }

        return SolarForecastResponse(
            latitude: 37.98,
            longitude: 23.72,
            timezone: TimeZone.current.identifier,
            hourly: .init(
                time: hourlyTimes,
                shortwave_radiation: Array(repeating: 500, count: hourlyTimes.count),
                direct_radiation: Array(repeating: 350, count: hourlyTimes.count),
                diffuse_radiation: Array(repeating: 150, count: hourlyTimes.count),
                direct_normal_irradiance: Array(repeating: 600, count: hourlyTimes.count),
                cloud_cover: Array(repeating: 20, count: hourlyTimes.count),
                is_day: Array(repeating: 1, count: hourlyTimes.count),
                weather_code: Array(repeating: 0, count: hourlyTimes.count),
                temperature_2m: Array(repeating: 22, count: hourlyTimes.count)
            ),
            daily: .init(
                time: dailyTimes,
                shortwave_radiation_sum: Array(repeating: radiationMJ, count: dailyTimes.count),
                sunrise: dailyTimes.map { "\($0)T06:00" },
                sunset: dailyTimes.map { "\($0)T20:00" },
                weather_code: Array(repeating: 0, count: dailyTimes.count)
            )
        )
    }

    static func horizonProfile(angle: Double) -> ElevationService.HorizonProfile {
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
}

private actor MockSolarForecastProvider: SolarForecastProviding {
    private let response: SolarForecastResponse

    init(response: SolarForecastResponse) {
        self.response = response
    }

    func fetchSolarForecast(
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) async throws -> SolarForecastResponse {
        response
    }
}
