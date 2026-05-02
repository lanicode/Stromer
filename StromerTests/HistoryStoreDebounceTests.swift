import SwiftData
import XCTest

@MainActor
final class HistoryStoreDebounceTests: XCTestCase {
    func testReadingsInsideOneSecondWriteOnlyOneLiveReading() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 10_000)

        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start, soc: 80))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(0.5), soc: 81))

        let liveRows = try store.context.fetch(FetchDescriptor<LiveReading>())
        let dailyRows = try store.context.fetch(FetchDescriptor<DailyAggregate>())

        XCTAssertEqual(liveRows.count, 1)
        XCTAssertEqual(dailyRows.first?.sampleCount, 2)
        XCTAssertEqual(dailyRows.first?.socMax, 81)
    }

    func testReadingAfterDebounceWritesSecondLiveReading() async throws {
        let store = try makeHistoryStore()
        let deviceID = UUID()
        let start = Date(timeIntervalSince1970: 10_000)

        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start, soc: 80))
        await store.recordReading(makeBatteryReading(deviceID: deviceID, timestamp: start.addingTimeInterval(1.1), soc: 81))

        let liveRows = try store.context.fetch(FetchDescriptor<LiveReading>())

        XCTAssertEqual(liveRows.count, 2)
    }
}
