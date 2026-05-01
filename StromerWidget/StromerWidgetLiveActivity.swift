import ActivityKit
import StromerScanner
import SwiftUI
import WidgetKit

struct StromerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StromerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: context.attributes.deviceTypeIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.deviceName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.secondary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    valueView(context.state, size: 34)
                }

                HStack(spacing: 8) {
                    freshnessBadge(context.state.freshness)
                    Text("Aktualisiert")
                        .foregroundStyle(.secondary)
                    Text(context.state.lastUpdated, style: .relative)
                        .monospacedDigit()
                }
                .font(.caption)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: context.attributes.deviceTypeIcon)
                            .font(.title3.weight(.semibold))
                        Text(context.attributes.deviceName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    valueView(context.state, size: 26)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        freshnessBadge(context.state.freshness)
                        Text("Aktualisiert")
                        Text(context.state.lastUpdated, style: .relative)
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.attributes.deviceTypeIcon)
            } compactTrailing: {
                Text(compactValue(context.state))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
            } minimal: {
                Text(compactValue(context.state))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .keylineTint(.accentColor)
        }
    }

    private func valueView(
        _ state: StromerActivityAttributes.ContentState,
        size: CGFloat
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(formattedValue(state.value))
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(state.unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func freshnessBadge(_ freshness: String) -> some View {
        Text(freshnessTitle(freshness))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(freshnessColor(freshness).opacity(0.16)))
            .foregroundStyle(freshnessColor(freshness))
    }

    private func compactValue(_ state: StromerActivityAttributes.ContentState) -> String {
        "\(formattedValue(state.value))\(state.unit)"
    }

    private func formattedValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }

    private func freshnessTitle(_ freshness: String) -> String {
        switch freshness {
        case DeviceFreshness.fresh.rawValue:
            return "Frisch"
        case DeviceFreshness.delayed.rawValue:
            return "Verzögert"
        case DeviceFreshness.stale.rawValue:
            return "Veraltet"
        case DeviceFreshness.missing.rawValue:
            return "Fehlt"
        default:
            return "Unklar"
        }
    }

    private func freshnessColor(_ freshness: String) -> Color {
        switch freshness {
        case DeviceFreshness.fresh.rawValue:
            return .green
        case DeviceFreshness.delayed.rawValue:
            return .yellow
        case DeviceFreshness.stale.rawValue:
            return .orange
        default:
            return .red
        }
    }
}
