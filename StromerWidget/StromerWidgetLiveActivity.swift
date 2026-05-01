import ActivityKit
import StromerScanner
import SwiftUI
import WidgetKit

struct StromerLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
    }

    let deviceName: String
}

struct StromerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StromerLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text("Stromer")
                    .font(.headline)
                Text(context.attributes.deviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.08))
            .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Stromer")
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
            } compactTrailing: {
                Text("OK")
            } minimal: {
                Image(systemName: "bolt.fill")
            }
        }
    }
}
