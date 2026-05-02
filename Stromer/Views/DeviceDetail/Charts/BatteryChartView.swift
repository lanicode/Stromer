import Charts
import SwiftUI

struct BatteryChartView: View {
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
            guard let soc = reading.soc else {
                return nil
            }
            return HistoryChartPoint(date: reading.timestamp, value: soc)
        }
        let sampled = HistoryChartDataMapper.downsample(points)
        let segments = HistoryChartDataMapper.lineSegments(points: sampled)

        if sampled.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(segments) { segment in
                    ForEach(segment.points) { point in
                        LineMark(
                            x: .value("Zeit", point.date),
                            y: .value("SoC", point.value),
                            series: .value("Segment", segment.id.uuidString)
                        )
                        .foregroundStyle(Color.boltTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { timeAxisMarks }
            .chartYAxis { percentAxisMarks }
            .frame(height: 220)

            HistoryChartFootnote(gapCount: HistoryChartDataMapper.gapCount(in: sampled))
        }
    }

    @ViewBuilder
    private var aggregateChart: some View {
        let ranges = minuteData.compactMap { aggregate -> HistoryRangePoint? in
            guard let min = aggregate.socMin,
                  let max = aggregate.socMax else {
                return nil
            }
            return HistoryRangePoint(
                date: aggregate.slotStart,
                min: min,
                max: max,
                avg: aggregate.socAvg
            )
        }

        if ranges.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(ranges) { point in
                    AreaMark(
                        x: .value("Zeit", point.date),
                        yStart: .value("Min", point.min),
                        yEnd: .value("Max", point.max)
                    )
                    .foregroundStyle(Color.boltTealSoft)

                    if let avg = point.avg {
                        LineMark(
                            x: .value("Zeit", point.date),
                            y: .value("Avg", avg)
                        )
                        .foregroundStyle(Color.boltTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { dayAxisMarks }
            .chartYAxis { percentAxisMarks }
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var yearChart: some View {
        let points = dailyData.compactMap { aggregate -> HistoryChartPoint? in
            let value = aggregate.socAvg
                ?? average(aggregate.socMin, aggregate.socMax)
            guard let value else {
                return nil
            }
            return HistoryChartPoint(date: aggregate.dayStart, value: value)
        }

        if points.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Tag", point.date),
                        y: .value("SoC", point.value)
                    )
                    .foregroundStyle(Color.boltTeal)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { monthAxisMarks }
            .chartYAxis { percentAxisMarks }
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
            liveData = []
            dailyData = []
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

    private var taskID: String {
        "\(deviceID.uuidString)-\(timeRange.rawValue)"
    }

    private func average(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return (lhs + rhs) / 2
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
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

    private var percentAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel()
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }
}
