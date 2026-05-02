import Foundation
import SwiftData

@Model
final class DailyAggregate {
    var deviceID: UUID
    var dayStart: Date
    var familyKind: String

    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var sampleCount: Int
    var gapCount: Int
    var observedMinutes: Double

    var yieldTodayMax: Double?
    var peakPvPower: Double?
    var sunHours: Double?

    var socMin: Double?
    var socMax: Double?
    var socAvg: Double?
    var voltageMin: Double?
    var voltageMax: Double?
    var deepDischargesCount: Int?
    var fullChargesCount: Int?

    var inputVoltageMin: Double?
    var inputVoltageMax: Double?
    var inputVoltageAvg: Double?
    var outputVoltageMin: Double?
    var outputVoltageMax: Double?
    var outputVoltageAvg: Double?
    var totalChargingMinutes: Double?
    var offReasonLastRaw: UInt32?

    init(
        deviceID: UUID,
        dayStart: Date,
        familyKind: String
    ) {
        self.deviceID = deviceID
        self.dayStart = dayStart
        self.familyKind = familyKind
        self.sampleCount = 0
        self.gapCount = 0
        self.observedMinutes = 0
        self.deepDischargesCount = 0
        self.fullChargesCount = 0
    }
}
