import Foundation
import StromerScanner
import SwiftData

@MainActor
final class SwiftDataHistoryStore: HistoryStore, DeviceReadingHistoryStoring, @unchecked Sendable {
    static let liveRetention: TimeInterval = 24 * 60 * 60
    static let minuteRetention: TimeInterval = 30 * 24 * 60 * 60
    static let liveGapThreshold: TimeInterval = 5 * 60
    static let aggregateGapThreshold: TimeInterval = 30 * 60
    static let debounceInterval: TimeInterval = 1
    static let fiveMinuteSlot: TimeInterval = 5 * 60
    static let storageWarningThresholdBytes: Int64 = 500 * 1024 * 1024

    static var schema: Schema {
        Schema([
            LiveReading.self,
            MinuteAggregate.self,
            DailyAggregate.self
        ])
    }

    let container: ModelContainer
    let context: ModelContext

    private var lastWriteTimestamps: [UUID: Date] = [:]
    private var lastAggregationDayByDevice: [UUID: Date] = [:]
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let storageDirectory: URL?

    convenience init() throws {
        let schema = Self.schema
        let configuration = ModelConfiguration(
            "StromerHistory",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        try self.init(container: container)
    }

    init(
        container: ModelContainer,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        storageDirectory: URL? = nil
    ) throws {
        self.container = container
        self.context = ModelContext(container)
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.storageDirectory = storageDirectory
    }

    func recordReading(_ reading: DeviceReading) async {
        let dayStart = calendar.startOfDay(for: reading.timestamp)
        if lastAggregationDayByDevice[reading.deviceID] != dayStart {
            lastAggregationDayByDevice[reading.deviceID] = dayStart
            await aggregateMinuteToDaily()
        }

        upsertDaily(reading: reading)

        if let lastWrite = lastWriteTimestamps[reading.deviceID],
           reading.timestamp.timeIntervalSince(lastWrite) < Self.debounceInterval {
            saveIgnoringErrors()
            return
        }

        context.insert(LiveReading(reading: reading))
        lastWriteTimestamps[reading.deviceID] = reading.timestamp
        saveIgnoringErrors()
    }

    func aggregateLiveToMinute() async {
        let cutoff = nowProvider().addingTimeInterval(-Self.liveRetention)
        let descriptor = FetchDescriptor<LiveReading>(
            predicate: #Predicate { $0.timestamp < cutoff },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let readings = try? context.fetch(descriptor), !readings.isEmpty else {
            return
        }

        let grouped = Dictionary(grouping: readings) { reading in
            MinuteBucketKey(
                deviceID: reading.deviceID,
                slotStart: slotStart(for: reading.timestamp),
                familyKind: reading.familyKind
            )
        }

        for (key, rows) in grouped {
            let aggregate = fetchMinuteAggregate(
                deviceID: key.deviceID,
                slotStart: key.slotStart
            ) ?? MinuteAggregate(
                deviceID: key.deviceID,
                slotStart: key.slotStart,
                familyKind: key.familyKind
            )

            applyLiveRows(rows, to: aggregate)

            if aggregate.modelContext == nil {
                context.insert(aggregate)
            }
        }

        if saveSucceeded() {
            readings.forEach(context.delete)
            saveIgnoringErrors()
        }
    }

    func aggregateMinuteToDaily() async {
        let cutoff = nowProvider().addingTimeInterval(-Self.minuteRetention)
        let descriptor = FetchDescriptor<MinuteAggregate>(
            predicate: #Predicate { $0.slotStart < cutoff },
            sortBy: [SortDescriptor(\.slotStart)]
        )

        guard let aggregates = try? context.fetch(descriptor), !aggregates.isEmpty else {
            return
        }

        let grouped = Dictionary(grouping: aggregates) { aggregate in
            DailyBucketKey(
                deviceID: aggregate.deviceID,
                dayStart: calendar.startOfDay(for: aggregate.slotStart),
                familyKind: aggregate.familyKind
            )
        }

        for (key, rows) in grouped {
            let daily = fetchDailyAggregate(
                deviceID: key.deviceID,
                dayStart: key.dayStart
            ) ?? DailyAggregate(
                deviceID: key.deviceID,
                dayStart: key.dayStart,
                familyKind: key.familyKind
            )

            applyMinuteRows(rows, to: daily)

            if daily.modelContext == nil {
                context.insert(daily)
            }
        }

        if saveSucceeded() {
            aggregates.forEach(context.delete)
            saveIgnoringErrors()
        }
    }

    func currentStorageSize() async -> Int64 {
        guard let storageDirectory else {
            return 0
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: storageDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    func deleteHistoryOlderThan(_ date: Date) async {
        let liveDescriptor = FetchDescriptor<LiveReading>(
            predicate: #Predicate { $0.timestamp < date }
        )
        let minuteDescriptor = FetchDescriptor<MinuteAggregate>(
            predicate: #Predicate { $0.slotStart < date }
        )
        let dailyDescriptor = FetchDescriptor<DailyAggregate>(
            predicate: #Predicate { $0.dayStart < date }
        )

        (try? context.fetch(liveDescriptor))?.forEach(context.delete)
        (try? context.fetch(minuteDescriptor))?.forEach(context.delete)
        (try? context.fetch(dailyDescriptor))?.forEach(context.delete)
        saveIgnoringErrors()
    }

    func liveReadings(deviceID: UUID, from: Date, to: Date) async -> [LiveReading] {
        let descriptor = FetchDescriptor<LiveReading>(
            predicate: #Predicate {
                $0.deviceID == deviceID
                    && $0.timestamp >= from
                    && $0.timestamp <= to
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func minuteAggregates(deviceID: UUID, from: Date, to: Date) async -> [MinuteAggregate] {
        let descriptor = FetchDescriptor<MinuteAggregate>(
            predicate: #Predicate {
                $0.deviceID == deviceID
                    && $0.slotStart >= from
                    && $0.slotStart <= to
            },
            sortBy: [SortDescriptor(\.slotStart)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func dailyAggregates(deviceID: UUID, from: Date, to: Date) async -> [DailyAggregate] {
        let descriptor = FetchDescriptor<DailyAggregate>(
            predicate: #Predicate {
                $0.deviceID == deviceID
                    && $0.dayStart >= from
                    && $0.dayStart <= to
            },
            sortBy: [SortDescriptor(\.dayStart)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func todayAggregate(deviceID: UUID) async -> DailyAggregate? {
        let dayStart = calendar.startOfDay(for: nowProvider())
        let descriptor = FetchDescriptor<DailyAggregate>(
            predicate: #Predicate {
                $0.deviceID == deviceID && $0.dayStart == dayStart
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func upsertDaily(reading: DeviceReading) {
        let dayStart = calendar.startOfDay(for: reading.timestamp)
        let daily = fetchDailyAggregate(
            deviceID: reading.deviceID,
            dayStart: dayStart
        ) ?? DailyAggregate(
            deviceID: reading.deviceID,
            dayStart: dayStart,
            familyKind: reading.payload.historyFamilyKind
        )

        let countBefore = daily.sampleCount
        updateObservedWindow(for: daily, timestamp: reading.timestamp)

        switch reading.payload {
        case let .batteryMonitor(payload):
            applyBattery(
                voltage: payload.batteryVoltage,
                current: payload.batteryCurrent,
                soc: payload.soc,
                consumed: payload.consumedAh,
                to: daily,
                countBefore: countBefore
            )

        case let .solarCharger(payload):
            applySolar(
                pvPower: payload.pvPower.map(Double.init),
                batteryVoltage: payload.batteryVoltage,
                batteryCurrent: payload.batteryCurrent,
                yieldToday: payload.yieldTodayWh,
                to: daily,
                countBefore: countBefore
            )

        case let .dcDcConverter(payload):
            applyDcDc(
                inputVoltage: payload.inputVoltage,
                outputVoltage: payload.outputVoltage,
                chargeStateRaw: payload.chargeStateRaw,
                offReasonRaw: payload.offReasonRaw,
                to: daily,
                countBefore: countBefore
            )
        }

        daily.sampleCount += 1

        if daily.modelContext == nil {
            context.insert(daily)
        }
    }

    private func updateObservedWindow(for daily: DailyAggregate, timestamp: Date) {
        if let firstSeenAt = daily.firstSeenAt {
            daily.firstSeenAt = min(firstSeenAt, timestamp)
        } else {
            daily.firstSeenAt = timestamp
        }

        guard let lastSeenAt = daily.lastSeenAt else {
            daily.lastSeenAt = timestamp
            return
        }

        let delta = timestamp.timeIntervalSince(lastSeenAt)
        if delta > Self.aggregateGapThreshold {
            daily.gapCount += 1
        }
        if delta > 0, delta <= Self.liveGapThreshold {
            daily.observedMinutes += delta / 60
        }
        if timestamp > lastSeenAt {
            daily.lastSeenAt = timestamp
        }
    }

    private func applyLiveRows(_ rows: [LiveReading], to aggregate: MinuteAggregate) {
        aggregate.familyKind = rows.first?.familyKind ?? aggregate.familyKind
        aggregate.sampleCount = rows.count

        aggregate.voltageMin = minValue(rows.compactMap(\.voltage))
        aggregate.voltageMax = maxValue(rows.compactMap(\.voltage))
        aggregate.voltageAvg = average(rows.compactMap(\.voltage))
        aggregate.currentMin = minValue(rows.compactMap(\.current))
        aggregate.currentMax = maxValue(rows.compactMap(\.current))
        aggregate.currentAvg = average(rows.compactMap(\.current))
        aggregate.socMin = minValue(rows.compactMap(\.soc))
        aggregate.socMax = maxValue(rows.compactMap(\.soc))
        aggregate.socAvg = average(rows.compactMap(\.soc))
        aggregate.consumedMin = minValue(rows.compactMap(\.consumed))
        aggregate.consumedMax = maxValue(rows.compactMap(\.consumed))

        aggregate.pvPowerMin = minValue(rows.compactMap(\.pvPower))
        aggregate.pvPowerMax = maxValue(rows.compactMap(\.pvPower))
        aggregate.pvPowerAvg = average(rows.compactMap(\.pvPower))
        aggregate.batteryVoltageMin = minValue(rows.compactMap(\.batteryVoltage))
        aggregate.batteryVoltageMax = maxValue(rows.compactMap(\.batteryVoltage))
        aggregate.batteryVoltageAvg = average(rows.compactMap(\.batteryVoltage))
        aggregate.batteryCurrentMin = minValue(rows.compactMap(\.batteryCurrent))
        aggregate.batteryCurrentMax = maxValue(rows.compactMap(\.batteryCurrent))
        aggregate.batteryCurrentAvg = average(rows.compactMap(\.batteryCurrent))
        aggregate.yieldTodayMax = maxValue(rows.compactMap(\.yieldToday))

        aggregate.inputVoltageMin = minValue(rows.compactMap(\.inputVoltage))
        aggregate.inputVoltageMax = maxValue(rows.compactMap(\.inputVoltage))
        aggregate.inputVoltageAvg = average(rows.compactMap(\.inputVoltage))
        aggregate.outputVoltageMin = minValue(rows.compactMap(\.outputVoltage))
        aggregate.outputVoltageMax = maxValue(rows.compactMap(\.outputVoltage))
        aggregate.outputVoltageAvg = average(rows.compactMap(\.outputVoltage))
        aggregate.activeMinutes = activeMinutes(for: rows)
    }

    private func applyMinuteRows(_ rows: [MinuteAggregate], to daily: DailyAggregate) {
        daily.familyKind = rows.first?.familyKind ?? daily.familyKind
        daily.sampleCount += rows.reduce(0) { $0 + $1.sampleCount }
        daily.firstSeenAt = minDate(daily.firstSeenAt, rows.map(\.slotStart).min())
        daily.lastSeenAt = maxDate(
            daily.lastSeenAt,
            rows.map { $0.slotStart.addingTimeInterval(Self.fiveMinuteSlot) }.max()
        )
        daily.observedMinutes += Double(rows.count) * 5
        daily.gapCount += aggregateGapCount(in: rows)

        daily.voltageMin = minValue([daily.voltageMin, minValue(rows.compactMap(\.voltageMin))].compactMap { $0 })
        daily.voltageMax = maxValue([daily.voltageMax, maxValue(rows.compactMap(\.voltageMax))].compactMap { $0 })
        daily.socMin = minValue([daily.socMin, minValue(rows.compactMap(\.socMin))].compactMap { $0 })
        daily.socMax = maxValue([daily.socMax, maxValue(rows.compactMap(\.socMax))].compactMap { $0 })
        daily.socAvg = weightedAverage(rows.compactMap { valueAndCount($0.socAvg, count: $0.sampleCount) })
            ?? daily.socAvg

        daily.yieldTodayMax = maxValue([daily.yieldTodayMax, maxValue(rows.compactMap(\.yieldTodayMax))].compactMap { $0 })
        daily.peakPvPower = maxValue([daily.peakPvPower, maxValue(rows.compactMap(\.pvPowerMax))].compactMap { $0 })
        daily.sunHours = (daily.sunHours ?? 0) + Double(rows.filter { ($0.pvPowerMax ?? 0) > 0 }.count) * 5 / 60

        daily.inputVoltageMin = minValue([daily.inputVoltageMin, minValue(rows.compactMap(\.inputVoltageMin))].compactMap { $0 })
        daily.inputVoltageMax = maxValue([daily.inputVoltageMax, maxValue(rows.compactMap(\.inputVoltageMax))].compactMap { $0 })
        daily.inputVoltageAvg = weightedAverage(rows.compactMap { valueAndCount($0.inputVoltageAvg, count: $0.sampleCount) })
            ?? daily.inputVoltageAvg
        daily.outputVoltageMin = minValue([daily.outputVoltageMin, minValue(rows.compactMap(\.outputVoltageMin))].compactMap { $0 })
        daily.outputVoltageMax = maxValue([daily.outputVoltageMax, maxValue(rows.compactMap(\.outputVoltageMax))].compactMap { $0 })
        daily.outputVoltageAvg = weightedAverage(rows.compactMap { valueAndCount($0.outputVoltageAvg, count: $0.sampleCount) })
            ?? daily.outputVoltageAvg
        daily.totalChargingMinutes = (daily.totalChargingMinutes ?? 0)
            + rows.reduce(0) { $0 + ($1.activeMinutes ?? 0) }
    }

    private func applyBattery(
        voltage: Double?,
        current: Double?,
        soc: Double?,
        consumed: Double?,
        to daily: DailyAggregate,
        countBefore: Int
    ) {
        daily.voltageMin = minOptional(daily.voltageMin, voltage)
        daily.voltageMax = maxOptional(daily.voltageMax, voltage)
        daily.socMin = minOptional(daily.socMin, soc)
        daily.socMax = maxOptional(daily.socMax, soc)
        daily.socAvg = updatedAverage(daily.socAvg, countBefore: countBefore, newValue: soc)
        _ = current
        _ = consumed
    }

    private func applySolar(
        pvPower: Double?,
        batteryVoltage: Double?,
        batteryCurrent: Double?,
        yieldToday: Double?,
        to daily: DailyAggregate,
        countBefore: Int
    ) {
        daily.yieldTodayMax = maxOptional(daily.yieldTodayMax, yieldToday)
        daily.peakPvPower = maxOptional(daily.peakPvPower, pvPower)
        daily.voltageMin = minOptional(daily.voltageMin, batteryVoltage)
        daily.voltageMax = maxOptional(daily.voltageMax, batteryVoltage)
        _ = batteryCurrent
        _ = countBefore
    }

    private func applyDcDc(
        inputVoltage: Double?,
        outputVoltage: Double?,
        chargeStateRaw: UInt8?,
        offReasonRaw: UInt32,
        to daily: DailyAggregate,
        countBefore: Int
    ) {
        daily.inputVoltageMin = minOptional(daily.inputVoltageMin, inputVoltage)
        daily.inputVoltageMax = maxOptional(daily.inputVoltageMax, inputVoltage)
        daily.inputVoltageAvg = updatedAverage(daily.inputVoltageAvg, countBefore: countBefore, newValue: inputVoltage)
        daily.outputVoltageMin = minOptional(daily.outputVoltageMin, outputVoltage)
        daily.outputVoltageMax = maxOptional(daily.outputVoltageMax, outputVoltage)
        daily.outputVoltageAvg = updatedAverage(daily.outputVoltageAvg, countBefore: countBefore, newValue: outputVoltage)
        daily.offReasonLastRaw = offReasonRaw

        if let chargeStateRaw, chargeStateRaw != 0, chargeStateRaw != 255 {
            daily.totalChargingMinutes = (daily.totalChargingMinutes ?? 0) + min(1, Self.debounceInterval / 60)
        }
    }

    private func fetchMinuteAggregate(deviceID: UUID, slotStart: Date) -> MinuteAggregate? {
        let descriptor = FetchDescriptor<MinuteAggregate>(
            predicate: #Predicate {
                $0.deviceID == deviceID && $0.slotStart == slotStart
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchDailyAggregate(deviceID: UUID, dayStart: Date) -> DailyAggregate? {
        let descriptor = FetchDescriptor<DailyAggregate>(
            predicate: #Predicate {
                $0.deviceID == deviceID && $0.dayStart == dayStart
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func slotStart(for date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / Self.fiveMinuteSlot) * Self.fiveMinuteSlot)
    }

    private func activeMinutes(for rows: [LiveReading]) -> Double? {
        let activeCount = rows.filter { row in
            if let state = row.dcDcChargeStateRaw {
                return state != 0 && state != 255
            }
            return row.outputVoltage != nil
        }.count

        guard activeCount > 0 else {
            return nil
        }

        return min(5, Double(activeCount) / 60)
    }

    private func aggregateGapCount(in rows: [MinuteAggregate]) -> Int {
        let slots = rows.map(\.slotStart).sorted()
        guard slots.count > 1 else {
            return 0
        }

        return zip(slots, slots.dropFirst()).reduce(0) { count, pair in
            pair.1.timeIntervalSince(pair.0) > Self.aggregateGapThreshold ? count + 1 : count
        }
    }

    private func valueAndCount(_ value: Double?, count: Int) -> WeightedValue? {
        guard let value, count > 0 else {
            return nil
        }
        return WeightedValue(value: value, count: count)
    }

    private func updatedAverage(_ existing: Double?, countBefore: Int, newValue: Double?) -> Double? {
        guard let newValue else {
            return existing
        }
        guard let existing, countBefore > 0 else {
            return newValue
        }
        return ((existing * Double(countBefore)) + newValue) / Double(countBefore + 1)
    }

    private func minOptional(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return min(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func maxOptional(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return max(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func minValue(_ values: [Double]) -> Double? {
        values.min()
    }

    private func maxValue(_ values: [Double]) -> Double? {
        values.max()
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private func weightedAverage(_ values: [WeightedValue]) -> Double? {
        let totalCount = values.reduce(0) { $0 + $1.count }
        guard totalCount > 0 else {
            return nil
        }
        let total = values.reduce(0) { $0 + ($1.value * Double($1.count)) }
        return total / Double(totalCount)
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return min(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return max(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func saveSucceeded() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    private func saveIgnoringErrors() {
        try? context.save()
    }
}

private struct MinuteBucketKey: Hashable {
    let deviceID: UUID
    let slotStart: Date
    let familyKind: String
}

private struct DailyBucketKey: Hashable {
    let deviceID: UUID
    let dayStart: Date
    let familyKind: String
}

private struct WeightedValue {
    let value: Double
    let count: Int
}
