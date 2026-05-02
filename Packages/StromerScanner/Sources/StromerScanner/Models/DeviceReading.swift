import Foundation
import VictronParser

public enum DeviceReadingKind: String, Codable, Equatable, Sendable {
    case solarCharger
    case batteryMonitor
    case dcDcConverter
}

public struct SolarChargerReading: Codable, Equatable, Sendable {
    public let deviceStateRaw: UInt8?
    public let chargerErrorCode: UInt8?
    public let batteryVoltage: Double?
    public let batteryCurrent: Double?
    public let yieldTodayWh: Double?
    public let pvPower: Int?
    public let loadCurrent: Double?
}

public struct BatteryMonitorReading: Codable, Equatable, Sendable {
    public let timeToGoMinutes: Int?
    public let batteryVoltage: Double?
    public let alarmReasonRaw: UInt16
    public let auxModeRaw: UInt8
    public let starterVoltage: Double?
    public let midpointVoltage: Double?
    public let temperatureCelsius: Double?
    public let batteryCurrent: Double?
    public let consumedAh: Double?
    public let soc: Double?
}

public struct DcDcConverterReading: Codable, Equatable, Sendable {
    public let chargeStateRaw: UInt8?
    public let chargerErrorCode: UInt8?
    public let inputVoltage: Double?
    public let outputVoltage: Double?
    public let offReasonRaw: UInt32
}

public enum DeviceReadingPayload: Codable, Equatable, Sendable {
    case solarCharger(SolarChargerReading)
    case batteryMonitor(BatteryMonitorReading)
    case dcDcConverter(DcDcConverterReading)
}

public struct DeviceReading: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let deviceID: UUID
    public let name: String
    public let localName: String?
    public let peripheralID: UUID?
    public let productID: UInt16
    public let recordType: UInt8
    public let modelName: String
    public let rssi: Int
    public let timestamp: Date
    public var freshness: DeviceFreshness
    public let payload: DeviceReadingPayload

    public init(
        id: UUID = UUID(),
        deviceID: UUID,
        name: String,
        localName: String?,
        peripheralID: UUID?,
        productID: UInt16,
        recordType: UInt8,
        modelName: String,
        rssi: Int,
        timestamp: Date,
        freshness: DeviceFreshness,
        payload: DeviceReadingPayload
    ) {
        self.id = id
        self.deviceID = deviceID
        self.name = name
        self.localName = localName
        self.peripheralID = peripheralID
        self.productID = productID
        self.recordType = recordType
        self.modelName = modelName
        self.rssi = rssi
        self.timestamp = timestamp
        self.freshness = freshness
        self.payload = payload
    }
}

extension DeviceReading {
    public init(
        device: RegisteredDevice,
        record: VictronRecord,
        rssi: Int,
        timestamp: Date,
        now: Date
    ) {
        switch record {
        case let .solarCharger(solar):
            self.init(
                deviceID: device.id,
                name: device.name,
                localName: device.localName,
                peripheralID: device.peripheralID,
                productID: solar.productID.rawValue,
                recordType: 0x01,
                modelName: solar.modelName,
                rssi: rssi,
                timestamp: timestamp,
                freshness: DeviceFreshness(lastSeenAt: timestamp, now: now),
                payload: .solarCharger(SolarChargerReading(
                    deviceStateRaw: solar.deviceState?.rawValue,
                    chargerErrorCode: solar.chargerErrorCode,
                    batteryVoltage: solar.batteryVoltage,
                    batteryCurrent: solar.batteryCurrent,
                    yieldTodayWh: solar.yieldTodayWh,
                    pvPower: solar.pvPower,
                    loadCurrent: solar.loadCurrent
                ))
            )

        case let .batteryMonitor(battery):
            self.init(
                deviceID: device.id,
                name: device.name,
                localName: device.localName,
                peripheralID: device.peripheralID,
                productID: battery.productID.rawValue,
                recordType: 0x02,
                modelName: battery.modelName,
                rssi: rssi,
                timestamp: timestamp,
                freshness: DeviceFreshness(lastSeenAt: timestamp, now: now),
                payload: .batteryMonitor(BatteryMonitorReading(
                    timeToGoMinutes: battery.timeToGoMinutes,
                    batteryVoltage: battery.batteryVoltage,
                    alarmReasonRaw: battery.alarmReason.rawValue,
                    auxModeRaw: battery.auxMode.rawValue,
                    starterVoltage: battery.starterVoltage,
                    midpointVoltage: battery.midpointVoltage,
                    temperatureCelsius: battery.temperatureCelsius,
                    batteryCurrent: battery.batteryCurrent,
                    consumedAh: battery.consumedAh,
                    soc: battery.soc
                ))
            )
        case let .dcDcConverter(dcDc):
            self.init(
                deviceID: device.id,
                name: device.name,
                localName: device.localName,
                peripheralID: device.peripheralID,
                productID: dcDc.productID.rawValue,
                recordType: 0x04,
                modelName: dcDc.modelName,
                rssi: rssi,
                timestamp: timestamp,
                freshness: DeviceFreshness(lastSeenAt: timestamp, now: now),
                payload: .dcDcConverter(DcDcConverterReading(
                    chargeStateRaw: dcDc.chargeState?.rawValue,
                    chargerErrorCode: dcDc.chargerErrorCode,
                    inputVoltage: dcDc.inputVoltage,
                    outputVoltage: dcDc.outputVoltage,
                    offReasonRaw: dcDc.offReason.rawValue
                ))
            )
        }
    }
}
