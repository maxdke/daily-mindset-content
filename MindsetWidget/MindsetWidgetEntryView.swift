import SwiftUI
import UIKit
import WidgetKit

struct MindsetWidgetEntryView: View {
    var entry: MindsetWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    /// Vom Nutzer frei gewählte Textfarbe (siehe QuoteStore.customTextColor) – gilt
    /// für jedes Widget-Design; ohne eigene Wahl (nil) bleibt WidgetStyle beim
    /// festen Farbschema des jeweiligen Designs.
    private var customTextColor: Color? { QuoteStore.shared.customTextColor }

    /// Vom Nutzer gewählte Schriftart für den Spruchtext (siehe QuoteStore.quoteFont) –
    /// global, unabhängig vom gewählten Widget-Design.
    private var quoteFont: QuoteFont { QuoteStore.shared.quoteFont }

    /// Ist ein Spruch angeheftet (Premium, siehe QuoteStore.pinnedQuoteID), wird der
    /// "Neuer Spruch"-Button ausgeblendet – Pin soll genau diesen einen Spruch dauerhaft
    /// festhalten, ein Button, der ihn überschreiben könnte, würde dem widersprechen
    /// (siehe auch NextQuoteIntent, der aus demselben Grund dann ein No-Op ist).
    private var isPinned: Bool { QuoteStore.shared.pinnedQuoteID != nil }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenView
        case .accessoryCircular:
            lockScreenCircularView
        case .accessoryInline:
            lockScreenInlineView
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
                .foregroundStyle(entry.style.accentTextColor)
            Text(entry.quote?.text ?? "Dein Mindset entscheidet, bevor die Umstände es tun.")
                .font(quoteFont.font(size: 14, weight: .medium))
                .foregroundStyle(entry.style.primaryTextColor(customTextColor: customTextColor))
                .minimumScaleFactor(0.7)
                .lineLimit(5)
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { backgroundGradient }
        .overlay(alignment: .bottomTrailing) {
            if !isPinned {
                nextQuoteButton
            }
        }
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.quote?.category.symbolName ?? "brain.head.profile")
                .font(.title2)
                .foregroundStyle(entry.style.accentTextColor)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.quote?.category.displayName.uppercased() ?? "MINDSET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry.style.accentTextColor)
                Text(entry.quote?.text ?? "Kleine Schritte, jeden Tag, schlagen große Pläne, die nie starten.")
                    .font(quoteFont.font(size: 15, weight: .medium))
                    .foregroundStyle(entry.style.primaryTextColor(customTextColor: customTextColor))
                    .lineLimit(4)
                if let author = entry.quote?.author {
                    Text("– \(author)")
                        .font(.system(size: 11))
                        .foregroundStyle(entry.style.secondaryTextColor(customTextColor: customTextColor))
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { backgroundGradient }
        .overlay(alignment: .bottomTrailing) {
            if !isPinned {
                nextQuoteButton
            }
        }
    }

    /// Interaktiver Button (App Intents, iOS 17+, siehe NextQuoteIntent): schaltet den
    /// Spruch direkt im Widget weiter, ohne die App zu öffnen. Bewusst dezent (kleines
    /// Icon in einer Glas-Kapsel) in der Ecke platziert, damit er den eigentlichen
    /// Spruchtext nicht überlagert, aber trotzdem gut genug zum Antippen bleibt.
    private var nextQuoteButton: some View {
        Button(intent: NextQuoteIntent()) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.style.secondaryTextColor(customTextColor: customTextColor))
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private var lockScreenView: some View {
        // Lock-Screen-Widgets rendert iOS ohnehin systemweit einfarbig/monochrom –
        // ein eigenes Farbschema hat hier keinen Effekt, daher bewusst unverändert.
        Text(entry.quote?.text ?? "Heute zählt.")
            .font(.system(size: 13, weight: .medium))
            .lineLimit(3)
            .containerBackground(for: .widget) { Color.clear }
    }

    /// Kreis-Widget neben der Uhr auf dem Sperrbildschirm: Platz reicht nur für ein
    /// Symbol, daher zeigen wir das Icon der aktuellen Kategorie statt Text.
    /// AccessoryWidgetBackground() liefert den system-typischen "Glas"-Kreis dahinter.
    private var lockScreenCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.quote?.category.symbolName ?? "brain.head.profile")
                .font(.system(size: 20, weight: .medium))
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    /// Einzeiliges Widget direkt neben der Digitaluhr auf dem Sperrbildschirm.
    /// iOS kürzt automatisch mit "…", daher reicht ein einfaches lineLimit(1).
    private var lockScreenInlineView: some View {
        Text(entry.quote?.text ?? "Dein Mindset entscheidet.")
            .lineLimit(1)
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var backgroundGradient: some View {
        switch entry.style {
        case .photo:
            if let uiImage = QuoteStore.shared.loadWidgetBackgroundImage() {
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    LinearGradient(
                        colors: [.black.opacity(0.15), .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Fallback, falls "Foto" gewählt ist, aber (noch) kein Bild gespeichert wurde.
                LinearGradient(colors: WidgetStyle.classic.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        default:
            LinearGradient(colors: entry.style.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview(as: .systemSmall) {
    MindsetWidget()
} timeline: {
    MindsetEntry(date: .now, quote: nil)
}
