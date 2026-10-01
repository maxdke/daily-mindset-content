import Foundation

/// Gemeinsam von App und Widget-Extension genutzter Datenzugriff.
/// Liest/schreibt in den App-Group-Container, damit beide Targets
/// denselben Stand sehen, ohne dass das Widget selbst Netzwerk-Calls macht.
final class QuoteStore {
    static let shared = QuoteStore()
    private init() {}

    private let defaults = AppGroup.sharedDefaults
    private let sharedQuotesFileName = "quotes.json"

    private enum Keys {
        static let isPremium = "isPremium"
        static let selectedCategories = "selectedCategories"
        static let lastRemoteFetch = "lastRemoteFetch"
    }

    // MARK: - Premium / Preferences

    var isPremium: Bool {
        get { defaults.bool(forKey: Keys.isPremium) }
        set { defaults.set(newValue, forKey: Keys.isPremium) }
    }

    var selectedCategories: Set<QuoteCategory> {
        get {
            guard let raw = defaults.array(forKey: Keys.selectedCategories) as? [String] else {
                return Set(QuoteCategory.freeCategories)
            }
            let parsed = Set(raw.compactMap(QuoteCategory.init(rawValue:)))
            return parsed.isEmpty ? Set(QuoteCategory.freeCategories) : parsed
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: Keys.selectedCategories) }
    }

    /// Kategorien, die JETZT tatsächlich angezeigt werden dürfen (abhängig vom Abo-Status).
    var allowedCategoriesNow: Set<QuoteCategory> {
        isPremium ? selectedCategories : Set(QuoteCategory.freeCategories)
    }

    var lastRemoteFetch: Date? {
        get { defaults.object(forKey: Keys.lastRemoteFetch) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastRemoteFetch) }
    }

    // MARK: - Quotes

    private var sharedQuotesURL: URL? {
        AppGroup.sharedContainerURL?.appendingPathComponent(sharedQuotesFileName)
    }

    /// Lädt zuerst die (ggf. von der Content-Pipeline nachgelieferte) Datei im
    /// geteilten Container; fällt zurück auf das gebündelte Seed-File, damit
    /// die App/das Widget nie komplett leer sind (auch offline, auch vor dem ersten Fetch).
    func loadAllQuotes() -> [Quote] {
        if let url = sharedQuotesURL,
           let data = try? Data(contentsOf: url),
           let batch = try? JSONDecoder().decode(QuoteBatch.self, from: data),
           !batch.quotes.isEmpty {
            return batch.quotes
        }
        return loadBundledSeedQuotes()
    }

    func loadBundledSeedQuotes() -> [Quote] {
        guard let url = Bundle.main.url(forResource: "quotes_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let batch = try? JSONDecoder().decode(QuoteBatch.self, from: data) else {
            return []
        }
        return batch.quotes
    }

    /// Wird von der App nach einem erfolgreichen Remote-Fetch aufgerufen (siehe RemoteQuoteService),
    /// damit das Widget beim nächsten Timeline-Reload frische, KI-generierte Sprüche sieht.
    func saveQuotes(_ batch: QuoteBatch) {
        guard let url = sharedQuotesURL else { return }
        if let data = try? JSONEncoder().encode(batch) {
            try? data.write(to: url, options: .atomic)
            lastRemoteFetch = Date()
        }
    }

    /// Spruch für ein bestimmtes Datum, eingeschränkt auf erlaubte Kategorien.
    func quote(for date: Date, allowedCategories: Set<QuoteCategory>) -> Quote? {
        let key = Quote.dateKey(for: date)
        let all = loadAllQuotes()

        if let exact = all.first(where: { $0.dateKey == key && allowedCategories.contains($0.category) }) {
            return exact
        }

        // Kein exakt für diesen Tag vorgenerierter Spruch vorhanden (z.B. Pipeline noch nicht
        // gelaufen) -> deterministische Auswahl aus dem Pool, damit das Widget nie leer bleibt.
        let pool = all.filter { allowedCategories.contains($0.category) }
        guard !pool.isEmpty else { return nil }
        // .magnitude statt abs(): vermeidet den (extrem seltenen) Overflow-Trap
        // von abs(Int.min) und funktioniert für jeden möglichen hashValue.
        let index = Int(key.hashValue.magnitude % UInt(pool.count))
        return pool[index]
    }

    /// Baut eine Serie von (Datum, Spruch)-Paaren für die Widget-Timeline.
    func upcomingQuotes(from date: Date, days: Int, allowedCategories: Set<QuoteCategory>) -> [(Date, Quote)] {
        var results: [(Date, Quote)] = []
        let calendar = Calendar.current
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let quote = quote(for: day, allowedCategories: allowedCategories) {
                results.append((day, quote))
            }
        }
        return results
    }
}
