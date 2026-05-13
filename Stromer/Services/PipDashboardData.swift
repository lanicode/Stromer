import Foundation
import StromerScanner

struct PipDashboardData: Equatable {
    let primaryValue: String
    let primaryUnit: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let relativeUpdatedText: String
    let isStale: Bool

    static func empty() -> PipDashboardData {
        PipDashboardData(
            primaryValue: "—",
            primaryUnit: "—",
            primaryLabel: "STROMER",
            secondaryValue: "—",
            secondaryLabel: "—",
            relativeUpdatedText: "—",
            isStale: false
        )
    }

    static func from(snapshot: StromerWidgetSnapshot, now: Date) -> PipDashboardData {
        guard snapshot.status == .ready,
              let first = snapshot.devices.first else {
            return empty()
        }

        let secondaryDevice = snapshot.devices.dropFirst().first
        let secondaryValue: String
        let secondaryLabel: String
        if let secondaryDevice {
            secondaryValue = "\(secondaryDevice.mainValue) \(secondaryDevice.mainUnit)"
            secondaryLabel = secondaryDevice.name
        } else {
            secondaryValue = "—"
            secondaryLabel = "—"
        }

        return PipDashboardData(
            primaryValue: first.mainValue,
            primaryUnit: first.mainUnit,
            primaryLabel: first.mainLabel.uppercased(),
            secondaryValue: secondaryValue,
            secondaryLabel: secondaryLabel,
            relativeUpdatedText: first.relativeLastUpdated,
            isStale: first.lastUpdated.map { now.timeIntervalSince($0) > 300 } ?? true
        )
    }
}
