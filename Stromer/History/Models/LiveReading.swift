import Foundation
import StromerScanner
import SwiftData

@Model
final class LiveReading {
    var deviceID: UUID
    var timestamp: Date
    var familyKind: String
    var productID: Int?
    var recordType: Int
    var rssi: Int?

    var voltage: Double?
    var current: Double?
    var soc: Double?
    var consumed: Double?
    var temperature: Double?
    var timeToGo: Int?

    var pvPower: Double?
    var batteryVoltage: Double?
    var batteryCurrent: Double?
    var yieldToday: Double?
    var loadCurrent: Double?
    var chargerStateRaw: Int?

    var inputVoltage: Double?
    var outputVoltage: Double?
    var dcDcChargeStateRaw: Int?
    var offReasonRaw: UInt32?

    init(
        deviceID: UUID,
        timestamp: Date,
        familyKind: String,
        productID: Int?,
        recordType: Int,
        rssi: Int?
    ) {
        self.deviceID = deviceID
        self.timestamp = timestamp
        self.familyKind = familyKind
        self.productID = productID
        self.recordType = recordType
        self.rssi = rssi
    }

    convenience init(reading: DeviceReading) {
        self.init(
            deviceID: reading.deviceID,
            timestamp: reading.timestamp,
            familyKind: reading.payload.historyFamilyKind,
            productID: Int(reading.productID),
            recordType: Int(reading.recordType),
            rssi: reading.rssi
        )

        switch reading.payload {
        case let .batteryMonitor(payload):
            voltage = payload.batteryVoltage
            current = payload.batteryCurrent
            soc = payload.soc
            consumed = payload.consumedAh
            temperature = payload.temperatureCelsius
            timeToGo = payload.timeToGoMinutes

        case let .solarCharger(payload):
            pvPower = payload.pvPower.map(Double.init)
            batteryVoltage = payload.batteryVoltage
            batteryCurrent = payload.batteryCurrent
            yieldToday = payload.yieldTodayWh
            loadCurrent = payload.loadCurrent
            chargerStateRaw = payload.deviceStateRaw.map(Int.init)

        case let .dcDcConverter(payload):
            inputVoltage = payload.inputVoltage
            outputVoltage = payload.outputVoltage
            dcDcChargeStateRaw = payload.chargeStateRaw.map(Int.init)
            offReasonRaw = payload.offReasonRaw
        }
    }
}

extension DeviceReadingPayload {
    var historyFamilyKind: String {
        switch self {
        case .batteryMonitor:
            return "battery"
        case .solarCharger:
            return "solar"
        case .dcDcConverter:
            return "dcdc"
        }
    }
}
