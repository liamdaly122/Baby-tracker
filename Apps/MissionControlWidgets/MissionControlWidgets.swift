import SwiftUI
import WidgetKit

@main
struct MissionControlWidgets: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

/// Phase 0 placeholder. Days to T-0, next deadline and rank arrive in Phase 4.
struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownWidget", provider: CountdownProvider()) { _ in
            Text("T-minus")
                .font(.headline)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Countdown")
        .description("Days to T-0.")
        .supportedFamilies([.systemSmall])
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(CountdownEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        completion(Timeline(entries: [CountdownEntry(date: .now)], policy: .never))
    }
}
