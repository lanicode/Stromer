import CoreLocation
import Foundation

struct EfficiencyFactor: Equatable, Sendable {
    let avgYieldWh: Double
    let maxYieldWh: Double
    let sampleDays: Int
    let confidence: Double
    let whPerRadiationMJ: Double
}

struct YieldEstimate: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let expectedWh: Double?
    let confidence: Double
    let horizonLossPercent: Double
    let sourceRadiationMJ: Double
}

@MainActor
final class YieldEstimator {
    private let historyStore: any HistoryStore
    private let solarService: any SolarForecastProviding
    private let calendar: Calendar

    init(
        historyStore: any HistoryStore,
        solarService: any SolarForecastProviding,
        calendar: Calendar = .current
    ) {
        self.historyStore = historyStore
        self.solarService = solarService
        self.calendar = calendar
    }

    func calculateEfficiencyFactor(
        deviceID: UUID,
        days: Int = 14
    ) async -> EfficiencyFactor? {
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return nil
        }

        let dailyAggregates = await historyStore.dailyAggregates(
            deviceID: deviceID,
            from: startDate,
            to: now
        )
        let solarDays = dailyAggregates
            .filter { $0.familyKind == "solar" && ($0.yieldTodayMax ?? 0) > 0 }

        guard solarDays.count >= 5 else {
            return nil
        }

        let yields = solarDays.compactMap(\.yieldTodayMax).filter { $0 > 0 }
        let avgYield = yields.reduce(0, +) / Double(yields.count)
        let maxYield = yields.max() ?? avgYield
        let confidence = min(1.0, Double(solarDays.count) / 14.0)

        return EfficiencyFactor(
            avgYieldWh: avgYield,
            maxYieldWh: maxYield,
            sampleDays: solarDays.count,
            confidence: confidence,
            whPerRadiationMJ: max(0, avgYield / 16.0)
        )
    }

    func estimateYield(
        deviceID: UUID,
        forDate date: Date,
        latitude: Double,
        longitude: Double,
        horizonProfile: ElevationService.HorizonProfile?
    ) async throws -> YieldEstimate {
        let forecast = try await solarService.fetchSolarForecast(
            latitude: latitude,
            longitude: longitude,
            forecastDays: 7
        )

        guard let dayIndex = forecast.dayIndex(for: date, calendar: calendar) else {
            return YieldEstimate(
                date: date,
                expectedWh: nil,
                confidence: 0,
                horizonLossPercent: 0,
                sourceRadiationMJ: 0
            )
        }

        let radiationMJ = (forecast.daily.shortwave_radiation_sum[safe: dayIndex] ?? nil) ?? 0
        let factor = await calculateEfficiencyFactor(deviceID: deviceID)
        let loss = horizonProfile.map {
            calculateHorizonLoss(
                forecast: forecast,
                date: date,
                latitude: latitude,
                longitude: longitude,
                horizonProfile: $0
            )
        } ?? 0
        let expected = factor.map {
            max(0, radiationMJ * $0.whPerRadiationMJ * (1 - loss))
        }

        return YieldEstimate(
            date: date,
            expectedWh: expected,
            confidence: factor?.confidence ?? 0,
            horizonLossPercent: loss * 100,
            sourceRadiationMJ: radiationMJ
        )
    }

    func calculateHorizonLoss(
        forecast: SolarForecastResponse,
        date: Date,
        latitude: Double,
        longitude: Double,
        horizonProfile: ElevationService.HorizonProfile
    ) -> Double {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let indexes = forecast.hourlyIndexes(for: date, calendar: calendar)
        var totalRadiation = 0.0
        var blockedRadiation = 0.0

        for index in indexes {
            let radiation = (forecast.hourly.shortwave_radiation[safe: index] ?? nil) ?? 0
            guard radiation > 0,
                  let timestamp = SolarForecastResponse.hourFormatter.date(from: forecast.hourly.time[index]) else {
                continue
            }

            totalRadiation += radiation
            let position = AstronomicalCalculator.sunPosition(at: timestamp, coordinate: coordinate)
            let horizonAngle = horizonProfile.horizonAngle(at: position.azimuthDegreesFromNorth)
            if position.altitudeDegrees < horizonAngle {
                blockedRadiation += radiation
            }
        }

        guard totalRadiation > 0 else {
            return 0
        }

        return min(max(blockedRadiation / totalRadiation, 0), 1)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
