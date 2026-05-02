import StromerScanner
import SwiftUI

struct DeviceRowView: View {
    let device: RegisteredDevice
    let reading: DeviceReading?

    var body: some View {
        let primary = DevicePresentation.primaryValue(for: reading, device: device)
        let freshness = DevicePresentation.freshness(for: device, reading: reading)

        HStack(spacing: 14) {
            Image(systemName: DevicePresentation.systemImage(for: device, reading: reading))
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(DevicePresentation.deviceKindTitle(for: device, reading: reading))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(primary.value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unit = primary.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                FreshnessBadge(freshness: freshness)
            }
        }
        .padding(.vertical, 4)
        .opacity(freshness == .stale || freshness == .missing ? 0.58 : 1)
        .accessibilityElement(children: .combine)
    }

    private var iconColor: Color {
        switch reading?.payload {
        case .batteryMonitor:
            return .green
        case .solarCharger:
            return .orange
        case .dcDcConverter:
            return .teal
        case nil:
            return .accentColor
        }
    }
}
