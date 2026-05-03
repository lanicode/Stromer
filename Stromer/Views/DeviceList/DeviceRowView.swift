import StromerScanner
import SwiftUI

struct DeviceRowView: View {
    let device: RegisteredDevice
    let reading: DeviceReading?
    let connectionStatus: ReceptionStatusObserver.ConnectionStatus
    let lastSeenText: String

    var body: some View {
        let primary = DevicePresentation.primaryValue(for: reading, device: device)
        let freshness = DevicePresentation.freshness(for: device, reading: reading)

        HStack(alignment: .top, spacing: 12) {
            leftRail

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Rectangle()
                        .fill(freshness.boltColor)
                        .frame(width: 7, height: 7)

                    Text(device.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.boltInk)
                        .lineLimit(1)
                }

                Text(metaLine)
                    .font(.boltMono(12))
                    .foregroundStyle(Color.boltInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                BoltSpark(
                    values: sparkValues,
                    color: freshness == .fresh ? .boltTeal : .boltInkFaint,
                    lineWidth: 1.5
                )
                .frame(width: 140, height: 18)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(primary.value)
                        .font(.system(size: 31, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color.boltInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    if let unit = primary.unit {
                        Text(unit)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.boltTeal)
                            .lineLimit(1)
                    }
                }
                .opacity(connectionStatus.dimsLiveValue ? 0.5 : 1)

                HStack(spacing: 4) {
                    if showsChargingBolt {
                        BoltGlyph(size: 9)
                    }

                    Text(stateLabel.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Color.boltInkSoft)
                        .lineLimit(1)
                }

                ConnectionStatusBadge(
                    status: connectionStatus,
                    lastSeenText: lastSeenText,
                    variant: .compact
                )
            }
        }
        .padding(14)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var leftRail: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: DevicePresentation.systemImage(for: device, reading: reading))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconForeground)
            }

            Text(kindShortLabel)
                .font(.boltMono(9))
                .fontWeight(.bold)
                .foregroundStyle(Color.boltInkSoft)
        }
        .frame(width: 42)
    }

    private var iconBackground: Color {
        switch kind {
        case .battery:
            return .boltTeal
        case .solar:
            return .boltYellow
        case .dcDc:
            return .boltTeal
        case .unknown:
            return .boltHair2
        }
    }

    private var iconForeground: Color {
        switch kind {
        case .solar:
            return .boltInkFixed
        case .battery, .dcDc, .unknown:
            return .boltCream
        }
    }

    private var kindShortLabel: String {
        switch kind {
        case .battery:
            return "BMV"
        case .solar:
            return "MPPT"
        case .dcDc:
            return "DCDC"
        case .unknown:
            return "BLE"
        }
    }

    private var metaLine: String {
        switch reading?.payload {
        case let .batteryMonitor(payload):
            return [
                payload.batteryVoltage.map { "\(DevicePresentation.number($0, digits: 2)) V" },
                payload.batteryCurrent.map { "\(DevicePresentation.number($0, digits: 1)) A" }
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty ?? DevicePresentation.deviceKindTitle(for: device, reading: reading)
        case let .solarCharger(payload):
            return [
                payload.batteryVoltage.map { "\(DevicePresentation.number($0, digits: 2)) V" },
                payload.batteryCurrent.map { "\(DevicePresentation.number($0, digits: 1)) A" }
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty ?? DevicePresentation.deviceKindTitle(for: device, reading: reading)
        case let .dcDcConverter(payload):
            let input = payload.inputVoltage.map { "\(DevicePresentation.number($0, digits: 1)) V" } ?? "--"
            let output = payload.outputVoltage.map { "\(DevicePresentation.number($0, digits: 1)) V" } ?? "--"
            return "\(input) -> \(output)"
        case nil:
            return DevicePresentation.deviceKindTitle(for: device, reading: reading)
        }
    }

    private var stateLabel: String {
        switch reading?.payload {
        case let .batteryMonitor(payload):
            guard let current = payload.batteryCurrent else {
                return "Neutral"
            }
            if current > 0.05 {
                return "Lädt"
            }
            if current < -0.05 {
                return "Entlädt"
            }
            return "Neutral"
        case let .solarCharger(payload):
            return DevicePresentation.chargerStateTitle(payload.deviceStateRaw)
        case let .dcDcConverter(payload):
            return DevicePresentation.chargerStateTitle(payload.chargeStateRaw)
        case nil:
            return "Wartet"
        }
    }

    private var showsChargingBolt: Bool {
        switch reading?.payload {
        case let .batteryMonitor(payload):
            return (payload.batteryCurrent ?? 0) > 0.05
        case let .solarCharger(payload):
            return payload.pvPower ?? 0 > 0
        case let .dcDcConverter(payload):
            return payload.chargeStateRaw != nil
                && DevicePresentation.chargerStateTitle(payload.chargeStateRaw) != "Aus"
        case nil:
            return false
        }
    }

    private var sparkValues: [Double] {
        switch reading?.payload {
        case let .batteryMonitor(payload):
            return sparklineValues(payload.batteryVoltage)
        case let .solarCharger(payload):
            return sparklineValues(payload.pvPower.map(Double.init))
        case let .dcDcConverter(payload):
            return sparklineValues(payload.outputVoltage ?? payload.inputVoltage)
        case nil:
            return []
        }
    }

    private func sparklineValues(_ value: Double?) -> [Double] {
        guard let value else {
            return []
        }
        return [value, value * 0.997, value * 1.002, value * 0.999, value]
    }

    private var kind: RowKind {
        switch reading?.payload {
        case .batteryMonitor:
            return .battery
        case .solarCharger:
            return .solar
        case .dcDcConverter:
            return .dcDc
        case nil:
            switch device.recordType {
            case 0x02:
                return .battery
            case 0x01:
                return .solar
            case 0x04:
                return .dcDc
            default:
                return .unknown
            }
        }
    }
}

private enum RowKind {
    case battery
    case solar
    case dcDc
    case unknown
}

extension DeviceFreshness {
    var boltColor: Color {
        switch self {
        case .fresh:
            return .boltOk
        case .delayed:
            return .boltWarn
        case .stale:
            return .boltInkFaint
        case .missing:
            return .boltBad
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
