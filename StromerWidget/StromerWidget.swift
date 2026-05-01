import StromerScanner
import SwiftUI
import WidgetKit

struct StromerWidgetEntry: TimelineEntry {
    let date: Date
}

struct StromerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StromerWidgetEntry {
        StromerWidgetEntry(date: .now)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (StromerWidgetEntry) -> Void
    ) {
        completion(StromerWidgetEntry(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<StromerWidgetEntry>) -> Void
    ) {
        let entry = StromerWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct StromerWidgetView: View {
    let entry: StromerWidgetEntry

    var body: some View {
        Text("Stromer")
            .font(.headline)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct StromerWidget: Widget {
    private let kind = "StromerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StromerWidgetProvider()) { entry in
            StromerWidgetView(entry: entry)
        }
        .configurationDisplayName("Stromer")
        .description("Zeigt Stromer Live-Werte.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    StromerWidget()
} timeline: {
    StromerWidgetEntry(date: .now)
}
