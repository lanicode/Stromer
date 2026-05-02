import Foundation
import Observation
import StromerScanner

struct DashboardInsight: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
}

struct DailyYieldPoint: Identifiable, Equatable {
    let date: Date
    let yieldWh: Double

    var id: Date { date }
}

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var currentSolarIn: Double?
    private(set) var currentLoadOut: Double?
    private(set) var currentNet: Double?

    private(set) var todaySolarYield: Double?
    private(set) var todayConsumption: Double?
    private(set) var todaySocMin: Double?
    private(set) var todaySocMax: Double?
    private(set) var todayFullCharges: Int?

    private(set) var insights: [DashboardInsight] = []
    private(set) var last7DaysYield: [DailyYieldPoint] = []
    private(set) var bestDayLabel: String?
    private(set) var bestDayYield: Double?

    @ObservationIgnored private let historyStore: (any HistoryStore)?
    @ObservationIgnored private let registeredDevicesProvider: () -> [RegisteredDevice]
    @ObservationIgnored private let latestReadingsProvider: () -> [DeviceReading]
    @ObservationIgnored private weak var sunsetService: SunsetService?
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private var lastLiveRefreshAt: Date?

    init(
        historyStore: (any HistoryStore)?,
        registeredDevicesProvider: @escaping () -> [RegisteredDevice],
        latestReadingsProvider: @escaping () -> [DeviceReading],
        sunsetService: SunsetService?,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.historyStore = historyStore
        self.registeredDevicesProvider = registeredDevicesProvider
        self.latestReadingsProvider = latestReadingsProvider
        self.sunsetService = sunsetService
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var hasDevices: Bool {
        !registeredDevicesProvider().isEmpty
    }

    var hasSolarDevice: Bool {
        registeredDevicesProvider().contains { $0.recordType == 0x01 }
    }

    func refresh() async {
        refreshLiveValues()

        let devices = registeredDevicesProvider()
        guard let historyStore, !devices.isEmpty else {
            clearHistoryDerivedValues()
            insights = generateInsights(yesterdaySolarYield: nil)
            return
        }

        let now = nowProvider()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let sevenDaysStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        var todaySolarTotal: Double = 0
        var yesterdaySolarTotal: Double = 0
        var sawTodaySolar = false
        var sawYesterdaySolar = false
        var socMins: [Double] = []
        var socMaxes: [Double] = []
        var fullCharges = 0
        var yieldByDay: [Date: Double] = [:]
        var consumptionWh = 0.0
        var sawConsumption = false

        for device in devices {
            if let today = await historyStore.todayAggregate(deviceID: device.id) {
                if let yieldTodayMax = today.yieldTodayMax {
                    todaySolarTotal += yieldTodayMax
                    sawTodaySolar = true
                }
                if let socMin = today.socMin {
                    socMins.append(socMin)
                }
                if let socMax = today.socMax {
                    socMaxes.append(socMax)
                }
                fullCharges += today.fullChargesCount ?? 0
            }

            let yesterdayRows = await historyStore.dailyAggregates(
                deviceID: device.id,
                from: yesterdayStart,
                to: todayStart.addingTimeInterval(-1)
            )
            if let yesterdayYield = yesterdayRows.compactMap(\.yieldTodayMax).max() {
                yesterdaySolarTotal += yesterdayYield
                sawYesterdaySolar = true
            }

            let weekRows = await historyStore.dailyAggregates(
                deviceID: device.id,
                from: sevenDaysStart,
                to: now
            )
            for row in weekRows {
                guard let yieldTodayMax = row.yieldTodayMax else {
                    continue
                }
                let day = calendar.startOfDay(for: row.dayStart)
                yieldByDay[day, default: 0] += yieldTodayMax
            }

            if device.recordType == 0x02 {
                let liveRows = await historyStore.liveReadings(
                    deviceID: device.id,
                    from: todayStart,
                    to: now
                )
                let estimate = Self.estimatedConsumptionWh(from: liveRows)
                if estimate > 0 {
                    consumptionWh += estimate
                    sawConsumption = true
                }
            }
        }

        if !sawTodaySolar {
            todaySolarTotal = latestReadingsProvider().reduce(0) { total, reading in
                guard case let .solarCharger(payload) = reading.payload,
                      let yieldTodayWh = payload.yieldTodayWh else {
                    return total
                }
                sawTodaySolar = true
                return total + yieldTodayWh
            }
        }

        let latestSocs = latestReadingsProvider().compactMap { reading -> Double? in
            guard case let .batteryMonitor(payload) = reading.payload else {
                return nil
            }
            return payload.soc
        }

        todaySolarYield = sawTodaySolar ? todaySolarTotal : nil
        todayConsumption = sawConsumption ? consumptionWh : nil
        todaySocMin = socMins.min() ?? latestSocs.min()
        todaySocMax = socMaxes.max() ?? latestSocs.max()
        todayFullCharges = fullCharges > 0 ? fullCharges : nil

        last7DaysYield = yieldByDay
            .map { DailyYieldPoint(date: $0.key, yieldWh: $0.value) }
            .sorted { $0.date < $1.date }
        let best = last7DaysYield.max { $0.yieldWh < $1.yieldWh }
        bestDayYield = best?.yieldWh
        bestDayLabel = best.map { weekdayLabel(for: $0.date) }

        insights = generateInsights(
            yesterdaySolarYield: sawYesterdaySolar ? yesterdaySolarTotal : nil
        )
    }

    func refreshLiveValues() {
        let now = nowProvider()
        if let lastLiveRefreshAt,
           now.timeIntervalSince(lastLiveRefreshAt) < 1 {
            return
        }
        lastLiveRefreshAt = now

        let readings = latestReadingsProvider()
        let solarPower = readings.reduce(0.0) { total, reading in
            guard case let .solarCharger(payload) = reading.payload,
                  let pvPower = payload.pvPower else {
                return total
            }
            return total + Double(pvPower)
        }

        let batteryPower = readings.reduce(0.0) { total, reading in
            guard case let .batteryMonitor(payload) = reading.payload,
                  let voltage = payload.batteryVoltage,
                  let current = payload.batteryCurrent else {
                return total
            }
            return total + Self.batteryPowerWatts(voltage: voltage, current: current)
        }

        let hasSolarPower = readings.contains {
            if case .solarCharger = $0.payload {
                return true
            }
            return false
        }
        let hasBatteryPower = readings.contains {
            if case let .batteryMonitor(payload) = $0.payload {
                return payload.batteryVoltage != nil && payload.batteryCurrent != nil
            }
            return false
        }

        currentSolarIn = hasSolarPower ? solarPower : nil
        currentNet = hasBatteryPower ? batteryPower : nil
        if hasSolarPower, hasBatteryPower {
            currentLoadOut = max(0, solarPower - batteryPower)
        } else if hasBatteryPower {
            currentLoadOut = max(0, -batteryPower)
        } else {
            currentLoadOut = nil
        }
    }

    static func batteryPowerWatts(voltage: Double, current: Double) -> Double {
        voltage * current
    }

    static func estimatedConsumptionWh(from readings: [LiveReading]) -> Double {
        let sorted = readings.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count > 1 else {
            return 0
        }

        return zip(sorted, sorted.dropFirst()).reduce(0) { total, pair in
            let delta = pair.1.timestamp.timeIntervalSince(pair.0.timestamp)
            guard delta > 0, delta <= SwiftDataHistoryStore.liveGapThreshold else {
                return total
            }
            guard let voltage = pair.0.voltage,
                  let current = pair.0.current else {
                return total
            }
            let watts = max(0, -batteryPowerWatts(voltage: voltage, current: current))
            return total + watts * (delta / 3_600)
        }
    }

    private func clearHistoryDerivedValues() {
        todaySolarYield = nil
        todayConsumption = nil
        todaySocMin = nil
        todaySocMax = nil
        todayFullCharges = nil
        last7DaysYield = []
        bestDayLabel = nil
        bestDayYield = nil
    }

    private func generateInsights(yesterdaySolarYield: Double?) -> [DashboardInsight] {
        var result: [DashboardInsight] = []

        if let todaySolarYield,
           let yesterdaySolarYield,
           yesterdaySolarYield > 0 {
            let percent = ((todaySolarYield - yesterdaySolarYield) / yesterdaySolarYield) * 100
            if abs(percent) >= 5 {
                let sign = percent > 0 ? "+" : ""
                result.append(DashboardInsight(
                    id: "solar-comparison",
                    icon: "bolt.fill",
                    text: "Heute \(sign)\(Int(percent.rounded()))% Solar als gestern"
                ))
            }
        }

        if let todaySocMin {
            result.append(DashboardInsight(
                id: "soc-min",
                icon: "battery.25",
                text: "Niedrigster SoC heute: \(Int(todaySocMin.rounded()))%"
            ))
        }

        if let todaySunset = sunsetService?.todaySunset {
            result.append(DashboardInsight(
                id: "sunset",
                icon: "sun.horizon.fill",
                text: "Nächster Sonnenuntergang: \(Self.timeFormatter.string(from: todaySunset))"
            ))
        }

        if result.isEmpty {
            result.append(DashboardInsight(
                id: "collecting",
                icon: "chart.xyaxis.line",
                text: "Stromer sammelt Daten für deine Energie-Bilanz."
            ))
        }

        return result
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeStyle = .short
        return formatter
    }()
}
