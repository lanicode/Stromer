import ActivityKit
import StromerScanner
import SwiftUI
import WidgetKit

struct StromerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StromerActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.boltInk)
                .activitySystemActionForegroundColor(Color.boltYellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        LiveActivityKindTile(
                            icon: context.attributes.deviceTypeIcon,
                            size: 34
                        )
                        Text(context.attributes.deviceName)
                            .font(.caption2.weight(.bold))
                            .lineLimit(2)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    valueView(context.state, size: 24)
                        .foregroundStyle(Color.boltYellow)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.state.secondary)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        relativeUpdatedText(context.state.lastUpdated)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.boltYellow)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        HStack(spacing: 7) {
                            freshnessSquare(context.state.freshness)
                            Text(freshnessTitle(context.state.freshness).uppercased())
                                .font(.caption2.weight(.heavy))
                                .tracking(1.0)
                            Spacer()
                            relativeUpdatedText(context.state.lastUpdated)
                                .font(.caption2.monospacedDigit())
                        }
                        .foregroundStyle(.secondary)

                        Capsule()
                            .fill(Color.boltYellow.opacity(0.35))
                            .frame(height: 2)
                    }
                }
            } compactLeading: {
                LiveActivityKindTile(
                    icon: context.attributes.deviceTypeIcon,
                    size: 18,
                    iconSize: 10
                )
            } compactTrailing: {
                Text(compactValue(context.state))
                    .font(.caption2.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.boltYellow)
                    .minimumScaleFactor(0.75)
            } minimal: {
                LiveActivityKindTile(
                    icon: context.attributes.deviceTypeIcon,
                    size: 18,
                    iconSize: 10
                )
            }
            .keylineTint(Color.boltYellow)
        }
    }

    private func valueView(
        _ state: StromerActivityAttributes.ContentState,
        size: CGFloat
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(formattedValue(state.value))
                .font(.system(size: size, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(state.unit)
                .font(.caption.weight(.bold))
        }
    }

    private func relativeUpdatedText(_ date: Date) -> Text {
        Text("VOR ") + Text(date, style: .relative)
    }

    private func freshnessSquare(_ freshness: String) -> some View {
        Rectangle()
            .fill(freshnessColor(freshness))
            .frame(width: 6, height: 6)
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
            return "Live"
        case DeviceFreshness.delayed.rawValue:
            return "Verzögert"
        case DeviceFreshness.stale.rawValue:
            return "Alt"
        case DeviceFreshness.missing.rawValue:
            return "Fehlt"
        default:
            return "Unklar"
        }
    }

    private func freshnessColor(_ freshness: String) -> Color {
        switch freshness {
        case DeviceFreshness.fresh.rawValue:
            return .boltOk
        case DeviceFreshness.delayed.rawValue:
            return .boltWarn
        case DeviceFreshness.stale.rawValue:
            return .boltWarn
        default:
            return .boltBad
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<StromerActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            LiveActivityKindTile(
                icon: context.attributes.deviceTypeIcon,
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    BoltWidgetSLockup(size: 16)
                    Text("Stromer · Live".uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color.boltYellow)
                }

                Text(context.attributes.deviceName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.boltCream)
                    .lineLimit(1)

                Text(context.state.secondary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.boltCream.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formattedValue(context.state.value))
                        .font(.system(size: 38, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color.boltYellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(context.state.unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.boltCream)
                }

                HStack(spacing: 5) {
                    BoltWidgetGlyph(
                        size: 9,
                        fillColor: .boltYellow,
                        strokeColor: .boltInk,
                        strokeWidth: 0.8
                    )
                    Text("VOR ")
                    Text(context.state.lastUpdated, style: .relative)
                }
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color.boltCream.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1A2129), Color(hex: 0x050708)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.boltYellow.opacity(0.4), lineWidth: 1)
        )
        .boltWidgetCornerNotch(size: 22)
    }

    private func formattedValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private struct LiveActivityKindTile: View {
    let icon: String
    var size: CGFloat
    var iconSize: CGFloat? = nil

    private var kind: BoltWidgetDeviceKind {
        BoltWidgetDeviceKind(icon: icon, title: icon)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(kind.tileColor)
            Image(systemName: icon)
                .font(.system(size: iconSize ?? size * 0.42, weight: .bold))
                .foregroundStyle(kind.iconColor)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
    }
}
