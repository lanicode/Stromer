import CoreLocation
import Foundation
import Observation
import StromerScanner

@MainActor
@Observable
final class SolarForecastViewModel {
    private(set) var todayEstimate: YieldEstimate?
    private(set) var weekEstimates: [YieldEstimate] = []
    private(set) var horizonProfile: ElevationService.HorizonProfile?
    private(set) var localHorizonTimes: LocalHorizonTimes?
    private(set) var efficiencyFactor: EfficiencyFactor?
    private(set) var loading = false
    private(set) var lastError: String?

    @ObservationIgnored private let estimator: YieldEstimator?
    @ObservationIgnored private let elevationService: ElevationService
    @ObservationIgnored private let sunsetService: SunsetService
    @ObservationIgnored private let settings: ForecastSettings
    @ObservationIgnored private let registeredDevicesProvider: () -> [RegisteredDevice]
    @ObservationIgnored private let calendar: Calendar

    init(
        estimator: YieldEstimator?,
        elevationService: ElevationService,
        sunsetService: SunsetService,
        settings: ForecastSettings,
        registeredDevicesProvider: @escaping () -> [RegisteredDevice],
        calendar: Calendar = .current
    ) {
        self.estimator = estimator
        self.elevationService = elevationService
        self.sunsetService = sunsetService
        self.settings = settings
        self.registeredDevicesProvider = registeredDevicesProvider
        self.calendar = calendar
    }

    func refresh() async {
        guard settings.isForecastEnabled else {
            clearForecast()
            return
        }

        guard let estimator else {
            lastError = "Historie nicht verfügbar."
            return
        }

        guard let mpptDevice = registeredDevicesProvider().first(where: { $0.recordType == 0x01 }) else {
            clearForecast()
            lastError = "Kein Solar-Regler registriert."
            return
        }

        guard let location = sunsetService.lastKnownLocation else {
            sunsetService.requestSingleLocationUpdate()
            clearForecast()
            lastError = "Standort nicht verfügbar."
            return
        }

        loading = true
        defer { loading = false }

        do {
            let coordinate = location.coordinate
            var profile: ElevationService.HorizonProfile?
            if settings.usesTopography {
                profile = try await elevationService.fetchHorizonProfile(
                    for: coordinate,
                    sampleDistanceKm: 5.0,
                    observerEyeHeight: 1.7
                )
            }

            horizonProfile = profile
            localHorizonTimes = profile.map {
                LocalHorizonCalculator.compute(
                    for: coordinate,
                    date: Date(),
                    horizon: $0
                )
            }
            efficiencyFactor = await estimator.calculateEfficiencyFactor(deviceID: mpptDevice.id)
            todayEstimate = try await estimator.estimateYield(
                deviceID: mpptDevice.id,
                forDate: Date(),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                horizonProfile: profile
            )

            var estimates: [YieldEstimate] = []
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else {
                    continue
                }
                let estimate = try await estimator.estimateYield(
                    deviceID: mpptDevice.id,
                    forDate: day,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    horizonProfile: profile
                )
                estimates.append(estimate)
            }
            weekEstimates = estimates
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func clearForecast() {
        todayEstimate = nil
        weekEstimates = []
        horizonProfile = nil
        localHorizonTimes = nil
        efficiencyFactor = nil
    }
}
