import Foundation
import Observation
import StromerScanner

struct SocRangePoint: Identifiable, Equatable {
    let date: Date
    let min: Double
    let max: Double
    let avg: Double?

    var id: Date { date }
}

struct DailyChargingPoint: Identifiable, Equatable {
    let date: Date
    let minutes: Double

    var id: Date { date }
}

struct ComparisonStats: Equatable {
    let title: String
    let detail: String
    let percentChange: Double?
}

enum HistoryOverviewRange: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Heute"
        case .sevenDays:
            return "7 Tage"
        case .thirtyDays:
            return "30 Tage"
        case .year:
            return "Jahr"
        }
    }
}

@MainActor
@Observable
final class HistoryViewModel {
    var timeRange: HistoryOverviewRange = .sevenDays

    private(set) var solarDailyData: [DailyYieldPoint] = []
    private(set) var totalSolarKwh: Double = 0
    private(set) var bestSolarDay: DailyYieldPoint?

    private(set) var batterySocRange: [SocRangePoint] = []
    private(set) var lowestSocDay: SocRangePoint?
    private(set) var totalFullCharges: Int = 0

    private(set) var dcDcChargingData: [DailyChargingPoint] = []
    private(set) var totalChargingHours: Double = 0

    private(set) var weekComparison: ComparisonStats?
    private(set) var monthComparison: ComparisonStats?

    @ObservationIgnored private let historyStore: (any HistoryStore)?
    @ObservationIgnored private let registeredDevicesProvider: () -> [RegisteredDevice]
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date

    init(
        historyStore: (any HistoryStore)?,
        registeredDevicesProvider: @escaping () -> [RegisteredDevice],
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.historyStore = historyStore
        self.registeredDevicesProvider = registeredDevicesProvider
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var hasDevices: Bool {
        !registeredDevicesProvider().isEmpty
    }

    var hasSolarSection: Bool {
        registeredDevicesProvider().contains { $0.recordType == 0x01 }
            || !solarDailyData.isEmpty
    }

    var hasBatterySection: Bool {
        registeredDevicesProvider().contains { $0.recordType == 0x02 }
            || !batterySocRange.isEmpty
    }

    var hasDcDcSection: Bool {
        registeredDevicesProvider().contains { $0.recordType == 0x04 }
            || !dcDcChargingData.isEmpty
    }

    func refresh() async {
        guard let historyStore else {
            clear()
            return
        }

        let devices = registeredDevicesProvider()
        guard !devices.isEmpty else {
            clear()
            return
        }

        let now = nowProvider()
        let interval = dailyInterval(for: timeRange, endingAt: now)
        let currentRows = await loadDailyRows(
            devices: devices,
            historyStore: historyStore,
            interval: interval
        )

        apply(rows: currentRows)
        weekComparison = await comparison(
            title: "Diese Woche vs. Vorwoche",
            devices: devices,
            historyStore: historyStore,
            days: 7,
            endingAt: now
        )
        monthComparison = await comparison(
            title: "Dieser Zeitraum vs. davor",
            devices: devices,
            historyStore: historyStore,
            days: max(7, Int(interval.duration / 86_400)),
            endingAt: now
        )
    }

    static func percentChange(current: Double, previous: Double) -> Double? {
        guard previous > 0 else {
            return nil
        }
        return ((current - previous) / previous) * 100
    }

    private func apply(rows: [DailyAggregate]) {
        let solarPoints = Self.aggregateDailyYields(rows, calendar: calendar)
        solarDailyData = solarPoints
        totalSolarKwh = solarPoints.reduce(0) { $0 + $1.yieldWh } / 1_000
        bestSolarDay = solarPoints.max { $0.yieldWh < $1.yieldWh }

        batterySocRange = Self.aggregateSocRanges(rows, calendar: calendar)
        lowestSocDay = batterySocRange.min { $0.min < $1.min }
        totalFullCharges = rows
            .filter { $0.familyKind == "battery" }
            .reduce(0) { $0 + ($1.fullChargesCount ?? 0) }

        dcDcChargingData = Self.aggregateChargingMinutes(rows, calendar: calendar)
        totalChargingHours = dcDcChargingData.reduce(0) { $0 + $1.minutes } / 60
    }

    static func aggregateDailyYields(
        _ rows: [DailyAggregate],
        calendar: Calendar = .current
    ) -> [DailyYieldPoint] {
        let grouped = Dictionary(grouping: rows.filter { $0.familyKind == "solar" }) {
            calendar.startOfDay(for: $0.dayStart)
        }

        return grouped.compactMap { day, rows in
            let sum = rows.compactMap(\.yieldTodayMax).reduce(0, +)
            guard sum > 0 else {
                return nil
            }
            return DailyYieldPoint(date: day, yieldWh: sum)
        }
        .sorted { $0.date < $1.date }
    }

    static func aggregateSocRanges(
        _ rows: [DailyAggregate],
        calendar: Calendar = .current
    ) -> [SocRangePoint] {
        let grouped = Dictionary(grouping: rows.filter { $0.familyKind == "battery" }) {
            calendar.startOfDay(for: $0.dayStart)
        }

        return grouped.compactMap { day, rows in
            let mins = rows.compactMap(\.socMin)
            let maxes = rows.compactMap(\.socMax)
            let avgs = rows.compactMap { row -> Double? in
                if let avg = row.socAvg {
                    return avg
                }
                switch (row.socMin, row.socMax) {
                case let (.some(min), .some(max)):
                    return (min + max) / 2
                case let (.some(min), .none):
                    return min
                case let (.none, .some(max)):
                    return max
                case (.none, .none):
                    return nil
                }
            }

            guard let min = mins.min(), let max = maxes.max() else {
                return nil
            }

            let avg = avgs.isEmpty ? nil : avgs.reduce(0, +) / Double(avgs.count)
            return SocRangePoint(date: day, min: min, max: max, avg: avg)
        }
        .sorted { $0.date < $1.date }
    }

    static func aggregateChargingMinutes(
        _ rows: [DailyAggregate],
        calendar: Calendar = .current
    ) -> [DailyChargingPoint] {
        let grouped = Dictionary(grouping: rows.filter { $0.familyKind == "dcdc" }) {
            calendar.startOfDay(for: $0.dayStart)
        }

        return grouped.compactMap { day, rows in
            let minutes = rows.compactMap(\.totalChargingMinutes).reduce(0, +)
            guard minutes > 0 else {
                return nil
            }
            return DailyChargingPoint(date: day, minutes: minutes)
        }
        .sorted { $0.date < $1.date }
    }

    private func dailyInterval(for range: HistoryOverviewRange, endingAt now: Date) -> DateInterval {
        let dayStart = calendar.startOfDay(for: now)
        switch range {
        case .today:
            return DateInterval(start: dayStart, end: now)
        case .sevenDays:
            return DateInterval(
                start: calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart,
                end: now
            )
        case .thirtyDays:
            return DateInterval(
                start: calendar.date(byAdding: .day, value: -29, to: dayStart) ?? dayStart,
                end: now
            )
        case .year:
            return DateInterval(
                start: calendar.date(byAdding: .day, value: -364, to: dayStart) ?? dayStart,
                end: now
            )
        }
    }

    private func comparison(
        title: String,
        devices: [RegisteredDevice],
        historyStore: any HistoryStore,
        days: Int,
        endingAt now: Date
    ) async -> ComparisonStats? {
        let todayStart = calendar.startOfDay(for: now)
        let currentStart = calendar.date(byAdding: .day, value: -days + 1, to: todayStart) ?? todayStart
        let previousStart = calendar.date(byAdding: .day, value: -days, to: currentStart) ?? currentStart
        let previousEnd = currentStart.addingTimeInterval(-1)

        let currentRows = await loadDailyRows(
            devices: devices,
            historyStore: historyStore,
            interval: DateInterval(start: currentStart, end: now)
        )
        let previousRows = await loadDailyRows(
            devices: devices,
            historyStore: historyStore,
            interval: DateInterval(start: previousStart, end: previousEnd)
        )

        let currentYield = Self.aggregateDailyYields(currentRows, calendar: calendar)
            .reduce(0) { $0 + $1.yieldWh }
        let previousYield = Self.aggregateDailyYields(previousRows, calendar: calendar)
            .reduce(0) { $0 + $1.yieldWh }

        guard currentYield > 0 || previousYield > 0 else {
            return nil
        }

        let percent = Self.percentChange(current: currentYield, previous: previousYield)
        let detail: String
        if let percent {
            let sign = percent >= 0 ? "+" : ""
            detail = "\(sign)\(Int(percent.rounded()))% Solar"
        } else {
            detail = "Noch kein Vergleichswert"
        }

        return ComparisonStats(
            title: title,
            detail: detail,
            percentChange: percent
        )
    }

    private func loadDailyRows(
        devices: [RegisteredDevice],
        historyStore: any HistoryStore,
        interval: DateInterval
    ) async -> [DailyAggregate] {
        var rows: [DailyAggregate] = []
        for device in devices {
            let deviceRows = await historyStore.dailyAggregates(
                deviceID: device.id,
                from: interval.start,
                to: interval.end
            )
            rows.append(contentsOf: deviceRows)
        }
        return rows.sorted { $0.dayStart < $1.dayStart }
    }

    private func clear() {
        solarDailyData = []
        totalSolarKwh = 0
        bestSolarDay = nil
        batterySocRange = []
        lowestSocDay = nil
        totalFullCharges = 0
        dcDcChargingData = []
        totalChargingHours = 0
        weekComparison = nil
        monthComparison = nil
    }
}
