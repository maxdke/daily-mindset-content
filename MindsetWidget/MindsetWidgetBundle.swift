import SwiftUI
import WidgetKit

@main
struct MindsetWidgetBundle: WidgetBundle {
    var body: some Widget {
        MindsetWidget()
    }
}

struct MindsetWidget: Widget {
    let kind: String = "MindsetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MindsetWidgetProvider()) { entry in
            MindsetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Mindset")
        .description("Täglich ein neuer Mindset-Spruch auf deinem Homescreen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
