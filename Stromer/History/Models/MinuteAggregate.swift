import Foundation
import SwiftData

@Model
final class MinuteAggregate {
    var deviceID: UUID
    var slotStart: Date
    var familyKind: String
    var sampleCount: Int

    var voltageMin: Double?
    var voltageMax: Double?
    var voltageAvg: Double?
    var currentMin: Double?
    var currentMax: Double?
    var currentAvg: Double?
    var socMin: Double?
    var socMax: Double?
    var socAvg: Double?
    var consumedMin: Double?
    var consumedMax: Double?

    var pvPowerMin: Double?
    var pvPowerMax: Double?
    var pvPowerAvg: Double?
    var batteryVoltageMin: Double?
    var batteryVoltageMax: Double?
    var batteryVoltageAvg: Double?
    var batteryCurrentMin: Double?
    var batteryCurrentMax: Double?
    var batteryCurrentAvg: Double?
    var yieldTodayMax: Double?

    var inputVoltageMin: Double?
    var inputVoltageMax: Double?
    var inputVoltageAvg: Double?
    var outputVoltageMin: Double?
    var outputVoltageMax: Double?
    var outputVoltageAvg: Double?
    var activeMinutes: Double?

    init(
        deviceID: UUID,
        slotStart: Date,
        familyKind: String,
        sampleCount: Int = 0
    ) {
        self.deviceID = deviceID
        self.slotStart = slotStart
        self.familyKind = familyKind
        self.sampleCount = sampleCount
    }
}
