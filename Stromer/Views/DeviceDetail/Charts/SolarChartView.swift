import Charts
import SwiftUI

struct SolarChartView: View {
    let deviceID: UUID
    let timeRange: ChartTimeRange
    let historyStore: (any HistoryStore)?

    @State private var liveData: [LiveReading] = []
    @State private var minuteData: [MinuteAggregate] = []
    @State private var dailyData: [DailyAggregate] = []

    var body: some View {
        VStack(spacing: 12) {
            switch timeRange {
            case .today:
                todayChart
            case .sevenDays, .thirtyDays:
                aggregateChart
            case .year:
                yearChart
            }
        }
        .task(id: taskID) {
            await loadData()
        }
    }

    @ViewBuilder
    private var todayChart: some View {
        let points = liveData.compactMap { reading -> HistoryChartPoint? in
            guard let pvPower = reading.pvPower else {
                return nil
            }
            return HistoryChartPoint(date: reading.timestamp, value: pvPower)
        }
        let sampled = HistoryChartDataMapper.downsample(points)

        if sampled.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let yieldToday = liveData.compactMap(\.yieldToday).max() {
                    Text("Ertrag heute \(DevicePresentation.number(yieldToday, digits: 0)) Wh")
                        .font(.boltMono(12))
                        .foregroundStyle(Color.boltInkSoft)
                }

                Chart {
                    ForEach(sampled) { point in
                        BarMark(
                            x: .value("Zeit", point.date),
                            y: .value("PV", point.value)
                        )
                        .foregroundStyle(Color.boltYellow)
                    }
                }
                .chartXAxis { timeAxisMarks }
                .chartYAxis { wattAxisMarks }
                .frame(height: 220)

                HistoryChartFootnote(gapCount: HistoryChartDataMapper.gapCount(in: sampled))
            }
        }
    }

    @ViewBuilder
    private var aggregateChart: some View {
        let points = dailyYieldPoints()

        if points.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Tag", point.date),
                        y: .value("Ertrag", point.value)
                    )
                    .foregroundStyle(Color.boltYellow)
                }
            }
            .chartXAxis { dayAxisMarks }
            .chartYAxis { whAxisMarks }
            .frame(height: 220)

            HistoryChartFootnote(gapCount: dailyData.reduce(0) { $0 + $1.gapCount })
        }
    }

    @ViewBuilder
    private var yearChart: some View {
        let points = dailyData.compactMap { aggregate -> HistoryChartPoint? in
            guard let yieldTodayMax = aggregate.yieldTodayMax else {
                return nil
            }
            return HistoryChartPoint(date: aggregate.dayStart, value: yieldTodayMax)
        }

        if points.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Tag", point.date),
                        y: .value("Ertrag", point.value)
                    )
                    .foregroundStyle(Color.boltYellow)
                }
            }
            .chartXAxis { monthAxisMarks }
            .chartYAxis { whAxisMarks }
            .frame(height: 220)

            HistoryChartFootnote(gapCount: dailyData.reduce(0) { $0 + $1.gapCount })
        }
    }

    private func loadData() async {
        guard let historyStore else {
            liveData = []
            minuteData = []
            dailyData = []
            return
        }

        let interval = timeRange.interval()
        switch timeRange {
        case .today:
            liveData = await historyStore.liveReadings(
                deviceID: deviceID,
                from: interval.start,
                to: interval.end
            )
            minuteData = []
            dailyData = []
        case .sevenDays, .thirtyDays:
            minuteData = await historyStore.minuteAggregates(
                deviceID: deviceID,
                from: interval.start,
                to: interval.end
            )
            dailyData = await historyStore.dailyAggregates(
                deviceID: deviceID,
                from: interval.start,
                to: interval.end
            )
            liveData = []
        case .year:
            dailyData = await historyStore.dailyAggregates(
                deviceID: deviceID,
                from: interval.start,
                to: interval.end
            )
            liveData = []
            minuteData = []
        }
    }

    private func dailyYieldPoints() -> [HistoryChartPoint] {
        let dailyPoints = dailyData.compactMap { aggregate -> HistoryChartPoint? in
            guard let value = aggregate.yieldTodayMax else {
                return nil
            }
            return HistoryChartPoint(date: aggregate.dayStart, value: value)
        }
        if !dailyPoints.isEmpty {
            return dailyPoints
        }

        let grouped = Dictionary(grouping: minuteData) { aggregate in
            Calendar.current.startOfDay(for: aggregate.slotStart)
        }

        return grouped.compactMap { day, rows in
            guard let maxYield = rows.compactMap(\.yieldTodayMax).max() else {
                return nil
            }
            return HistoryChartPoint(date: day, value: maxYield)
        }
        .sorted { $0.date < $1.date }
    }

    private var taskID: String {
        "\(deviceID.uuidString)-\(timeRange.rawValue)"
    }

    private var timeAxisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel(format: .dateTime.hour().minute())
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }

    private var dayAxisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel(format: .dateTime.day().month())
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }

    private var monthAxisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel(format: .dateTime.month(.abbreviated))
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }

    private var wattAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel()
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }

    private var whAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel()
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }
}
