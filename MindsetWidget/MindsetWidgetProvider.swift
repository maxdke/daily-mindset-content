import WidgetKit

/// WICHTIG: Diese Extension ruft NIE das Netzwerk auf. Sie liest ausschließlich,
/// was die App zuletzt über QuoteStore.saveQuotes(...) in den App-Group-Container
/// geschrieben hat (siehe RemoteQuoteService in der Haupt-App). So bleibt das
/// Widget schnell und verbraucht kein eigenes Refresh-Budget für Netzwerk-I/O.
struct MindsetWidgetProvider: TimelineProvider {
    private let store = QuoteStore.shared

    func placeholder(in context: Context) -> MindsetEntry {
        MindsetEntry(date: Date(), quote: store.loadBundledSeedQuotes().first, style: store.selectedWidgetStyle)
    }

    func getSnapshot(in context: Context, completion: @escaping (MindsetEntry) -> Void) {
        // Premium-Check: Free-Nutzer bleiben beim "classic"-Default, auch falls vor
        // einem abgelaufenen Abo mal ein anderer Stil (oder ein Pin) gesetzt war.
        let style = store.isPremium ? store.selectedWidgetStyle : .classic
        if store.isPremium, let pinned = store.pinnedQuote() {
            completion(MindsetEntry(date: Date(), quote: pinned, style: style))
            return
        }
        let allowed = store.allowedCategoriesNow
        // "Neuer Spruch"-Button im Widget (siehe NextQuoteIntent/QuoteStore.widgetOverrideQuote):
        // überschreibt für den Rest des heutigen Tages die normale Tagesrotation.
        let quote = store.widgetOverrideQuote() ?? store.quote(for: Date(), allowedCategories: allowed)
        completion(MindsetEntry(date: Date(), quote: quote, style: style))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MindsetEntry>) -> Void) {
        // Premium-Check: Free-Nutzer bleiben beim "classic"-Default, auch falls vor
        // einem abgelaufenen Abo mal ein anderer Stil (oder ein Pin) gesetzt war.
        let style = store.isPremium ? store.selectedWidgetStyle : .classic

        // Angehefteter Spruch: zeigt IMMER denselben Spruch statt der Tagesrotation,
        // bis der Nutzer ihn in der App wieder löst. Ein einziger Eintrag mit
        // Policy .never reicht – die App stößt bei Pin/Lösen sofort reloadAllTimelines() an.
        if store.isPremium, let pinned = store.pinnedQuote() {
            let entry = MindsetEntry(date: Date(), quote: pinned, style: style)
            completion(Timeline(entries: [entry], policy: .never))
            return
        }

        let allowed = store.allowedCategoriesNow
        let upcoming = store.upcomingQuotes(from: Date(), days: 7, allowedCategories: allowed)
        let calendar = Calendar.current

        // "Neuer Spruch"-Button im Widget (siehe NextQuoteIntent/QuoteStore.widgetOverrideQuote):
        // überschreibt nur den HEUTIGEN (ersten) Eintrag – für alle folgenden Tage gilt
        // wieder ganz normal die automatische Rotation, da der Override ohnehin nur für
        // den aktuellen Tag gespeichert wird (siehe QuoteStore.widgetOverrideQuoteID).
        let override = store.widgetOverrideQuote()
        let entries: [MindsetEntry] = upcoming.enumerated().map { index, pair in
            let (day, quote) = pair
            // Der erste Eintrag muss ab "jetzt" gelten, alle folgenden ab Mitternacht des jeweiligen Tages.
            let entryDate = index == 0 ? Date() : calendar.startOfDay(for: day)
            let resolvedQuote = (index == 0 ? override : nil) ?? quote
            return MindsetEntry(date: entryDate, quote: resolvedQuote, style: style)
        }

        // .atEnd: Sobald der letzte geplante Eintrag erreicht ist, fragt WidgetKit
        // uns automatisch erneut an (zusätzlich zum OS-Refresh-Budget).
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
