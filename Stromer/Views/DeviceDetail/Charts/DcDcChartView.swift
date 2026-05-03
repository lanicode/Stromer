import Charts
import SwiftUI

struct DcDcChartView: View {
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
        let outputPoints = liveData.compactMap { reading -> HistoryChartPoint? in
            guard let value = reading.outputVoltage else {
                return nil
            }
            return HistoryChartPoint(date: reading.timestamp, value: value)
        }
        let inputPoints = liveData.compactMap { reading -> HistoryChartPoint? in
            guard let value = reading.inputVoltage else {
                return nil
            }
            return HistoryChartPoint(date: reading.timestamp, value: value)
        }
        let sampledOutput = HistoryChartDataMapper.downsample(outputPoints)
        let sampledInput = HistoryChartDataMapper.downsample(inputPoints)

        if sampledOutput.isEmpty && sampledInput.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(HistoryChartDataMapper.lineSegments(points: sampledOutput)) { segment in
                    ForEach(segment.points) { point in
                        LineMark(
                            x: .value("Zeit", point.date),
                            y: .value("Ausgang", point.value),
                            series: .value("Ausgang", "out-\(segment.id.uuidString)")
                        )
                        .foregroundStyle(Color.boltTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }

                ForEach(HistoryChartDataMapper.lineSegments(points: sampledInput)) { segment in
                    ForEach(segment.points) { point in
                        LineMark(
                            x: .value("Zeit", point.date),
                            y: .value("Eingang", point.value),
                            series: .value("Eingang", "in-\(segment.id.uuidString)")
                        )
                        .foregroundStyle(Color.boltInkSoft)
                        .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .square, lineJoin: .miter))
                    }
                }
            }
            .chartXAxis { stromerDateAxis(for: timeRange.axisRange) }
            .chartYAxis { voltAxisMarks }
            .frame(height: 220)

            legend
            HistoryChartFootnote(gapCount: HistoryChartDataMapper.gapCount(in: sampledOutput + sampledInput))
        }
    }

    @ViewBuilder
    private var aggregateChart: some View {
        let ranges = minuteData.compactMap { aggregate -> HistoryRangePoint? in
            guard let min = aggregate.outputVoltageMin,
                  let max = aggregate.outputVoltageMax else {
                return nil
            }
            return HistoryRangePoint(
                date: aggregate.slotStart,
                min: min,
                max: max,
                avg: aggregate.outputVoltageAvg
            )
        }
        let inputPoints = minuteData.compactMap { aggregate -> HistoryChartPoint? in
            guard let value = aggregate.inputVoltageAvg else {
                return nil
            }
            return HistoryChartPoint(date: aggregate.slotStart, value: value)
        }

        if ranges.isEmpty && inputPoints.isEmpty {
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
                            y: .value("Ausgang", avg)
                        )
                        .foregroundStyle(Color.boltTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }

                ForEach(inputPoints) { point in
                    LineMark(
                        x: .value("Zeit", point.date),
                        y: .value("Eingang", point.value)
                    )
                    .foregroundStyle(Color.boltInkSoft)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .square, lineJoin: .miter))
                }
            }
            .chartXAxis { stromerDateAxis(for: timeRange.axisRange) }
            .chartYAxis { voltAxisMarks }
            .frame(height: 220)

            legend
        }
    }

    @ViewBuilder
    private var yearChart: some View {
        let ranges = dailyData.compactMap { aggregate -> HistoryRangePoint? in
            guard let min = aggregate.outputVoltageMin,
                  let max = aggregate.outputVoltageMax else {
                return nil
            }
            return HistoryRangePoint(
                date: aggregate.dayStart,
                min: min,
                max: max,
                avg: aggregate.outputVoltageAvg
            )
        }

        if ranges.isEmpty {
            HistoryChartEmptyState(timeRange: timeRange)
        } else {
            Chart {
                ForEach(ranges) { point in
                    AreaMark(
                        x: .value("Tag", point.date),
                        yStart: .value("Min", point.min),
                        yEnd: .value("Max", point.max)
                    )
                    .foregroundStyle(Color.boltTealSoft)

                    if let avg = point.avg {
                        LineMark(
                            x: .value("Tag", point.date),
                            y: .value("Ausgang", avg)
                        )
                        .foregroundStyle(Color.boltTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }
            }
            .chartXAxis { stromerDateAxis(for: timeRange.axisRange) }
            .chartYAxis { voltAxisMarks }
            .frame(height: 220)

            if let minutes = totalChargingMinutes {
                Text("Ladezeit im Zeitraum \(DevicePresentation.number(minutes, digits: 0)) Min.")
                    .font(.boltMono(12))
                    .foregroundStyle(Color.boltInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HistoryChartFootnote(gapCount: dailyData.reduce(0) { $0 + $1.gapCount })
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .boltTeal, title: "Ausgang")
            legendItem(color: .boltInkSoft, title: "Eingang")
            Spacer()
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(title.uppercased())
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
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

    private var totalChargingMinutes: Double? {
        let total = dailyData.reduce(0) { $0 + ($1.totalChargingMinutes ?? 0) }
        return total > 0 ? total : nil
    }

    private var taskID: String {
        "\(deviceID.uuidString)-\(timeRange.rawValue)"
    }

    private var voltAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
            AxisGridLine().foregroundStyle(Color.boltHair2)
            AxisTick().foregroundStyle(Color.boltHair)
            AxisValueLabel()
                .font(.boltMono(10))
                .foregroundStyle(Color.boltInkSoft)
        }
    }
}
