import SwiftUI
import WidgetKit

struct MindsetWidgetEntryView: View {
    var entry: MindsetWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.quote?.category.displayName.uppercased() ?? "MINDSET")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
            Text(entry.quote?.text ?? "Dein Mindset entscheidet, bevor die Umstände es tun.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(5)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { backgroundGradient }
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.quote?.category.symbolName ?? "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.quote?.category.displayName.uppercased() ?? "MINDSET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(entry.quote?.text ?? "Kleine Schritte, jeden Tag, schlagen große Pläne, die nie starten.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                if let author = entry.quote?.author {
                    Text("– \(author)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { backgroundGradient }
    }

    private var lockScreenView: some View {
        Text(entry.quote?.text ?? "Heute zählt.")
            .font(.system(size: 13, weight: .medium))
            .lineLimit(3)
            .containerBackground(for: .widget) { Color.clear }
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview(as: .systemSmall) {
    MindsetWidget()
} timeline: {
    MindsetEntry(date: .now, quote: nil)
}
