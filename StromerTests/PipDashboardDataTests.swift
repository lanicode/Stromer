import Foundation
import StromerScanner
import XCTest

final class PipDashboardDataTests: XCTestCase {
    func testEmpty() {
        let data = PipDashboardData.empty()

        XCTAssertEqual(data.primaryValue, "—")
        XCTAssertEqual(data.primaryUnit, "—")
        XCTAssertEqual(data.primaryLabel, "STROMER")
        XCTAssertEqual(data.secondaryValue, "—")
        XCTAssertEqual(data.secondaryLabel, "—")
        XCTAssertEqual(data.relativeUpdatedText, "—")
        XCTAssertFalse(data.isStale)
    }

    func testFromSnapshotReadyWithTwoDevices() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(
            devices: [
                makeDevice(
                    name: "SmartShunt",
                    mainLabel: "Batterie",
                    mainValue: "85",
                    mainUnit: "%",
                    lastUpdated: now.addingTimeInterval(-4),
                    relativeLastUpdated: "vor 4 Sek."
                ),
                makeDevice(
                    name: "MPPT 100/30",
                    mainLabel: "Solar jetzt",
                    mainValue: "189",
                    mainUnit: "W",
                    lastUpdated: now.addingTimeInterval(-3),
                    relativeLastUpdated: "vor 3 Sek."
                )
            ]
        )

        let data = PipDashboardData.from(snapshot: snapshot, now: now)

        XCTAssertEqual(data.primaryValue, "85")
        XCTAssertEqual(data.primaryUnit, "%")
        XCTAssertEqual(data.primaryLabel, "BATTERIE")
        XCTAssertEqual(data.secondaryValue, "189 W")
        XCTAssertEqual(data.secondaryLabel, "MPPT 100/30")
        XCTAssertEqual(data.relativeUpdatedText, "vor 4 Sek.")
        XCTAssertFalse(data.isStale)
    }

    func testFromSnapshotReadyWithOneDeviceFillsSecondaryWithDash() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(
            devices: [
                makeDevice(
                    name: "SmartShunt",
                    mainLabel: "Batterie",
                    mainValue: "85",
                    mainUnit: "%",
                    lastUpdated: now,
                    relativeLastUpdated: "gerade eben"
                )
            ]
        )

        let data = PipDashboardData.from(snapshot: snapshot, now: now)

        XCTAssertEqual(data.secondaryValue, "—")
        XCTAssertEqual(data.secondaryLabel, "—")
    }

    func testFromSnapshotMarksStaleWhenOlderThanFiveMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(
            devices: [
                makeDevice(
                    name: "SmartShunt",
                    mainLabel: "Batterie",
                    mainValue: "85",
                    mainUnit: "%",
                    lastUpdated: now.addingTimeInterval(-360),
                    relativeLastUpdated: "vor 6 Min."
                )
            ]
        )

        let data = PipDashboardData.from(snapshot: snapshot, now: now)

        XCTAssertTrue(data.isStale)
    }

    func testFromSnapshotNonReadyReturnsEmpty() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let noDevices = makeSnapshot(status: .noDevices, devices: [])
        let deviceMissing = makeSnapshot(status: .deviceMissing, devices: [])

        XCTAssertEqual(PipDashboardData.from(snapshot: noDevices, now: now), .empty())
        XCTAssertEqual(PipDashboardData.from(snapshot: deviceMissing, now: now), .empty())
    }

    private func makeSnapshot(
        status: StromerWidgetSnapshotStatus = .ready,
        devices: [StromerWidgetDeviceSnapshot]
    ) -> StromerWidgetSnapshot {
        StromerWidgetSnapshot(
            date: Date(timeIntervalSinceReferenceDate: 900),
            devices: devices,
            status: status,
            message: ""
        )
    }

    private func makeDevice(
        name: String,
        mainLabel: String,
        mainValue: String,
        mainUnit: String,
        lastUpdated: Date?,
        relativeLastUpdated: String
    ) -> StromerWidgetDeviceSnapshot {
        StromerWidgetDeviceSnapshot(
            id: UUID(),
            name: name,
            deviceTypeIcon: "bolt.fill",
            deviceTypeTitle: "Victron",
            mainLabel: mainLabel,
            mainValue: mainValue,
            mainUnit: mainUnit,
            secondary: "",
            lastUpdated: lastUpdated,
            relativeLastUpdated: relativeLastUpdated,
            freshness: .fresh
        )
    }
}
