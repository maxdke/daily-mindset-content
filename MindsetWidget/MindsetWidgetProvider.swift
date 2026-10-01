import WidgetKit

/// WICHTIG: Diese Extension ruft NIE das Netzwerk auf. Sie liest ausschließlich,
/// was die App zuletzt über QuoteStore.saveQuotes(...) in den App-Group-Container
/// geschrieben hat (siehe RemoteQuoteService in der Haupt-App). So bleibt das
/// Widget schnell und verbraucht kein eigenes Refresh-Budget für Netzwerk-I/O.
struct MindsetWidgetProvider: TimelineProvider {
    private let store = QuoteStore.shared

    func placeholder(in context: Context) -> MindsetEntry {
        MindsetEntry(date: Date(), quote: store.loadBundledSeedQuotes().first)
    }

    func getSnapshot(in context: Context, completion: @escaping (MindsetEntry) -> Void) {
        let allowed = store.allowedCategoriesNow
        let quote = store.quote(for: Date(), allowedCategories: allowed)
        completion(MindsetEntry(date: Date(), quote: quote))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MindsetEntry>) -> Void) {
        let allowed = store.allowedCategoriesNow
        let upcoming = store.upcomingQuotes(from: Date(), days: 7, allowedCategories: allowed)
        let calendar = Calendar.current

        let entries: [MindsetEntry] = upcoming.enumerated().map { index, pair in
            let (day, quote) = pair
            // Der erste Eintrag muss ab "jetzt" gelten, alle folgenden ab Mitternacht des jeweiligen Tages.
            let entryDate = index == 0 ? Date() : calendar.startOfDay(for: day)
            return MindsetEntry(date: entryDate, quote: quote)
        }

        // .atEnd: Sobald der letzte geplante Eintrag erreicht ist, fragt WidgetKit
        // uns automatisch erneut an (zusätzlich zum OS-Refresh-Budget).
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
