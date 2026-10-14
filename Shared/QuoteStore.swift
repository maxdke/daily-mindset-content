import Foundation
import SwiftUI
import UIKit

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
        static let widgetStyle = "selectedWidgetStyle"
        static let widgetBackgroundImageData = "widgetBackgroundImageData"
        static let customTextColorHex = "customTextColorHex"
        static let quoteFont = "quoteFont"
        static let favoriteQuoteIDs = "favoriteQuoteIDs"
        static let pinnedQuoteID = "pinnedQuoteID"
        static let widgetOverrideQuoteID = "widgetOverrideQuoteID"
        static let widgetOverrideDateKey = "widgetOverrideDateKey"
        static let currentStreak = "currentStreak"
        static let lastStreakDateKey = "lastStreakDateKey"
        static let customQuotes = "customQuotes"
    }

    // MARK: - Premium / Preferences

    var isPremium: Bool {
        get { defaults.bool(forKey: Keys.isPremium) }
        set { defaults.set(newValue, forKey: Keys.isPremium) }
    }

    /// Es lässt sich bewusst immer nur GENAU EINE Kategorie auswählen (siehe
    /// ContentView.categoryPicker) – der Tages-/Widget-Spruch kommt ohnehin nur aus
    /// einer einzigen Kategorie, mehrere gleichzeitig ausgewählt zu haben, würde also
    /// nur suggerieren, dass alle einfließen, obwohl de facto nur noch zufällig
    /// zwischen ihnen gemischt würde. Ältere, vor diesem Umbau gespeicherte Mehrfach-
    /// Auswahlen werden beim Lesen defensiv auf eine einzelne Kategorie reduziert.
    var selectedCategories: Set<QuoteCategory> {
        get {
            guard let raw = defaults.array(forKey: Keys.selectedCategories) as? [String] else {
                return Set(QuoteCategory.freeCategories)
            }
            let parsed = Set(raw.compactMap(QuoteCategory.init(rawValue:)))
            // .first auf einem Set ist NICHT deterministisch (wie bei String.hashValue,
            // siehe quote(for:allowedCategories:)) – stattdessen über die feste
            // Reihenfolge von QuoteCategory.allCases gehen, damit App und Widget
            // (getrennte Prozesse) bei einer alten Mehrfach-Auswahl dieselbe Kategorie wählen.
            guard let first = QuoteCategory.allCases.first(where: parsed.contains) else {
                return Set(QuoteCategory.freeCategories)
            }
            return [first]
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

    /// Ausgewähltes Widget-Design (Premium-Feature). Default "classic" für neue Installs
    /// und für Free-Nutzer, die (noch) nicht umgestellt haben.
    var selectedWidgetStyle: WidgetStyle {
        get {
            guard let raw = defaults.string(forKey: Keys.widgetStyle),
                  let style = WidgetStyle(rawValue: raw) else {
                return .classic
            }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.widgetStyle) }
    }

    /// Frei wählbare Textfarbe für das Widget-Design "Foto" (Premium-Feature,
    /// siehe WidgetStyle.photo) – ein festes Weiß ist nicht auf jedem eigenen
    /// Foto gut lesbar, daher kann der Nutzer selbst eine Farbe wählen.
    /// Default (noch nie gesetzt oder ungültiger Wert) bleibt Weiß, damit sich
    /// am bisherigen Look nichts ändert, solange niemand aktiv etwas wählt.
    /// Frei wählbare Textfarbe (Premium-Feature) für Widget + Teilen-Bild – überschreibt,
    /// wenn gesetzt, die feste, pro Widget-Design hinterlegte Farbe (siehe WidgetStyle).
    /// nil heißt bewusst "noch nichts gewählt" -> dann bleibt es beim jeweiligen
    /// Design-Farbschema. Betrifft NICHT die Hauptkarte in der App, die ist immer
    /// einfarbig/systemfarbig und unabhängig vom Widget-Design gehalten, damit sie in
    /// jedem Fall gut lesbar bleibt (eine frei wählbare Farbe könnte dort je nach Wahl
    /// mit dem festen hellen Kartenhintergrund kollidieren).
    var customTextColor: Color? {
        get {
            guard let hex = defaults.string(forKey: Keys.customTextColorHex) else { return nil }
            return Color(hexString: hex)
        }
        set {
            if let newValue {
                defaults.set(newValue.hexString, forKey: Keys.customTextColorHex)
            } else {
                defaults.removeObject(forKey: Keys.customTextColorHex)
            }
        }
    }

    /// Frei wählbare Schriftart für den Spruchtext (Premium-Feature, siehe QuoteFont) –
    /// wirkt global, unabhängig vom gewählten Widget-Design. Default (noch nie gesetzt
    /// oder ungültiger Wert) ist .serif: Das Teilen-Bild nutzte vorher fest eine Serifen-
    /// schrift (wirkte hochwertiger als die System-Schrift), damit bleibt der bisherige
    /// Look dort exakt erhalten, solange niemand aktiv etwas anderes wählt.
    var quoteFont: QuoteFont {
        get {
            guard let raw = defaults.string(forKey: Keys.quoteFont),
                  let font = QuoteFont(rawValue: raw) else {
                return .serif
            }
            return font
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.quoteFont) }
    }

    // MARK: - Favoriten
    //
    // Gespeichert als Set von Quote.id (category+date+index, siehe Quote.swift),
    // nicht als volle Quote-Objekte – so bleibt der gespeicherte Wert winzig und
    // übersteht auch einen künftigen Wortlaut-Fix an einem Spruch unbeschadet,
    // da nur die ID referenziert wird.

    var favoriteQuoteIDs: Set<String> {
        get {
            guard let raw = defaults.array(forKey: Keys.favoriteQuoteIDs) as? [String] else { return [] }
            return Set(raw)
        }
        set { defaults.set(Array(newValue), forKey: Keys.favoriteQuoteIDs) }
    }

    func isFavorite(_ quote: Quote) -> Bool {
        favoriteQuoteIDs.contains(quote.id)
    }

    func toggleFavorite(_ quote: Quote) {
        var ids = favoriteQuoteIDs
        if ids.contains(quote.id) {
            ids.remove(quote.id)
        } else {
            ids.insert(quote.id)
        }
        favoriteQuoteIDs = ids
    }

    /// Lädt die vollständigen Quote-Objekte zu den gespeicherten Favoriten-IDs.
    /// Durchsucht sowohl die aktuell geteilte Datei als auch das gebündelte
    /// Seed-File, damit auch ältere Favoriten erhalten bleiben, falls die
    /// Content-Pipeline zwischenzeitlich einen neuen Batch nachgeliefert hat.
    func favoriteQuotes() -> [Quote] {
        let ids = favoriteQuoteIDs
        guard !ids.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [Quote] = []
        for quote in loadAllQuotes() + loadBundledSeedQuotes() + customQuotes where ids.contains(quote.id) {
            guard !seen.contains(quote.id) else { continue }
            seen.insert(quote.id)
            result.append(quote)
        }
        return result
    }

    // MARK: - Widget-Pin
    //
    // Erlaubt, einen einzelnen Spruch dauerhaft fürs Widget festzulegen, statt der
    // automatischen Tagesrotation. Premium-Feature (siehe AppViewModel.pinQuote),
    // ähnlich wie Widget-Design/Kategorien – anders als die kostenlosen Favoriten.

    var pinnedQuoteID: String? {
        get { defaults.string(forKey: Keys.pinnedQuoteID) }
        set { defaults.set(newValue, forKey: Keys.pinnedQuoteID) }
    }

    func pinnedQuote() -> Quote? {
        guard let id = pinnedQuoteID else { return nil }
        return (loadAllQuotes() + loadBundledSeedQuotes() + customQuotes).first { $0.id == id }
    }

    // MARK: - Widget-Button "Neuer Spruch"
    //
    // Kostenloses Feature (wie das Durchblättern in der App), ausgelöst per
    // interaktivem Button direkt im Home-Screen-Widget (siehe NextQuoteIntent) –
    // bewusst GETRENNT vom Pin-Feature oben: Pin hält einen Spruch dauerhaft fest, bis
    // der Nutzer ihn aktiv löst; der Override hier gilt nur für den HEUTIGEN Tag und
    // verfällt danach automatisch (dateKey-Abgleich, gleiches Muster wie
    // lastStreakDateKey), damit am nächsten Tag wieder ganz normal der frische
    // Tagesspruch erscheint, ohne dass irgendwo aktiv aufgeräumt werden müsste.

    var widgetOverrideQuoteID: String? {
        get {
            guard defaults.string(forKey: Keys.widgetOverrideDateKey) == Quote.dateKey(for: Date()) else {
                return nil
            }
            return defaults.string(forKey: Keys.widgetOverrideQuoteID)
        }
        set {
            defaults.set(newValue, forKey: Keys.widgetOverrideQuoteID)
            defaults.set(newValue == nil ? nil : Quote.dateKey(for: Date()), forKey: Keys.widgetOverrideDateKey)
        }
    }

    func widgetOverrideQuote() -> Quote? {
        guard let id = widgetOverrideQuoteID else { return nil }
        return (loadAllQuotes() + loadBundledSeedQuotes() + customQuotes).first { $0.id == id }
    }

    /// Schaltet den Override auf den nächsten Spruch aus der Browsing-Liste
    /// (appearedQuotes) weiter, zyklisch durch alle erlaubten Kategorien – ausgehend
    /// vom aktuell angezeigten Spruch (Override, falls schon einer gesetzt ist, sonst
    /// der normale Tagesspruch), damit ein erneutes Antippen spürbar weiterblättert
    /// statt zufällig hin- und herzuspringen.
    @discardableResult
    func advanceWidgetOverride(allowedCategories: Set<QuoteCategory>) -> Quote? {
        let pool = appearedQuotes(allowedCategories: allowedCategories)
        guard !pool.isEmpty else { return nil }
        let currentID = widgetOverrideQuoteID ?? quote(for: Date(), allowedCategories: allowedCategories)?.id
        let nextIndex: Int
        if let currentID, let idx = pool.firstIndex(where: { $0.id == currentID }) {
            nextIndex = (idx + 1) % pool.count
        } else {
            nextIndex = 0
        }
        let next = pool[nextIndex]
        widgetOverrideQuoteID = next.id
        return next
    }

    /// Alle Sprüche, die bereits "dran waren" (dateKey <= heute) und in einer aktuell
    /// erlaubten Kategorie liegen – Basis für die manuelle Auswahl fürs Widget, damit
    /// Nutzer keine künftigen, noch ungesehenen Sprüche vorab zu sehen bekommen.
    /// Das gebündelte Seed-File (Fallback, bevor die Content-Pipeline je geliefert hat)
    /// markiert seine Einträge bewusst mit dateKey == "seed" statt einem echten Datum,
    /// da sie zu keinem bestimmten Tag gehören – die zählen hier immer als "erschienen",
    /// und zwar absichtlich ZUSÄTZLICH zu echten, datierten Pipeline-Sprüchen (nicht nur
    /// als Fallback, wenn gar keine da sind): Die Pipeline liefert nur Sprüche ab heute
    /// in die Zukunft, nie rückwirkend – an den ersten Tagen (oder direkt nach einem
    /// Pipeline-Update) gäbe es sonst oft nur 1 "erschienenen" Spruch pro Kategorie
    /// (den heutigen) und Durchblättern/Spruch-Auswahl fürs Widget wäre quasi leer.
    /// Die Seed-Sprüche füllen das auf; echte, datierte Sprüche werden unten trotzdem
    /// immer zuerst sortiert, Seed-Einträge kommen danach.
    func appearedQuotes(allowedCategories: Set<QuoteCategory>) -> [Quote] {
        let todayKey = Quote.dateKey(for: Date())
        var seen = Set<String>()
        var result: [Quote] = []
        var source = loadAllQuotes() + loadBundledSeedQuotes()
        if allowedCategories.contains(.custom) {
            source += customQuotes
        }
        for quote in source
        where allowedCategories.contains(quote.category) && (quote.dateKey == "seed" || quote.dateKey <= todayKey) {
            guard !seen.contains(quote.id) else { continue }
            seen.insert(quote.id)
            result.append(quote)
        }
        // Echte, datierte Sprüche zuerst (neueste zuerst), Seed-Fallback-Einträge danach.
        return result.sorted { lhs, rhs in
            if lhs.dateKey == "seed" && rhs.dateKey != "seed" { return false }
            if rhs.dateKey == "seed" && lhs.dateKey != "seed" { return true }
            return lhs.dateKey > rhs.dateKey
        }
    }

    // MARK: - Streak
    //
    // Kostenloses Motivations-Feature (bewusst KEIN Premium-Feature, siehe
    // AppViewModel.recordDailyOpen): zählt an wie vielen Tagen in Folge die App
    // geöffnet wurde. Ein Tag zählt, sobald die App an diesem Tag mindestens
    // einmal geöffnet wird – nicht erst bei bestimmten Interaktionen.

    var currentStreak: Int {
        get { defaults.integer(forKey: Keys.currentStreak) }
        set { defaults.set(newValue, forKey: Keys.currentStreak) }
    }

    private var lastStreakDateKey: String? {
        get { defaults.string(forKey: Keys.lastStreakDateKey) }
        set { defaults.set(newValue, forKey: Keys.lastStreakDateKey) }
    }

    /// Wird beim App-Start aufgerufen. Erhöht den Streak um 1, wenn die App zuletzt
    /// genau gestern geöffnet wurde; setzt ihn auf 1 zurück, wenn ein Tag (oder mehr)
    /// ausgelassen wurde oder dies der allererste Start ist; bleibt unverändert,
    /// wenn die App heute bereits geöffnet wurde (mehrfaches Öffnen am selben Tag
    /// zählt nicht doppelt). Gibt den aktuellen Streak-Wert zurück.
    @discardableResult
    func recordAppOpenForStreak() -> Int {
        let todayKey = Quote.dateKey(for: Date())
        guard lastStreakDateKey != todayKey else { return currentStreak }

        let calendar = Calendar.current
        if let lastKey = lastStreakDateKey,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
           lastKey == Quote.dateKey(for: yesterday) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        lastStreakDateKey = todayKey
        return currentStreak
    }

    // MARK: - Eigene Sprüche
    //
    // Vom Nutzer selbst geschriebene Sprüche (kostenloses Feature, siehe
    // AppViewModel.addCustomQuote). Bewusst getrennt von den KI-generierten
    // Sprüchen gespeichert (eigenes JSON in den geteilten UserDefaults statt
    // der Content-Pipeline-Datei), damit sie nie von einem neuen Remote-Fetch
    // überschrieben werden. Nehmen NICHT an der Tagesrotation teil (siehe
    // quote(for:allowedCategories:)/appearedQuotes) – nur fürs manuelle
    // Favorisieren, ans Widget heften und Teilen gedacht, daher müssen
    // favoriteQuotes()/pinnedQuote() oben zusätzlich hier nachschauen.

    var customQuotes: [Quote] {
        get {
            guard let data = defaults.data(forKey: Keys.customQuotes),
                  let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
                return []
            }
            return quotes
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.customQuotes)
            }
        }
    }

    @discardableResult
    func addCustomQuote(text: String, author: String?) -> Quote {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author?.trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = Quote(
            id: "custom-\(UUID().uuidString)",
            text: trimmedText,
            author: (trimmedAuthor?.isEmpty ?? true) ? nil : trimmedAuthor,
            category: .custom,
            dateKey: Quote.dateKey(for: Date())
        )
        var quotes = customQuotes
        quotes.insert(quote, at: 0)
        customQuotes = quotes
        return quote
    }

    func deleteCustomQuote(id: String) {
        customQuotes.removeAll { $0.id == id }
        if pinnedQuoteID == id {
            pinnedQuoteID = nil
        }
        if favoriteQuoteIDs.contains(id) {
            favoriteQuoteIDs.remove(id)
        }
    }

    // MARK: - Quotes

    private var sharedQuotesURL: URL? {
        AppGroup.sharedContainerURL?.appendingPathComponent(sharedQuotesFileName)
    }

    // MARK: - Eigenes Widget-Hintergrundbild ("Foto"-Design)
    //
    // WICHTIG: Bewusst über die geteilten UserDefaults (App-Group-Suite) gespeichert,
    // NICHT als Datei im App-Group-Container. Grund: UserDefaults(suiteName:) ist der
    // Mechanismus, der bei uns nachweislich zuverlässig zwischen App und Widget-Extension
    // funktioniert (Kategorien, Premium-Status, Widget-Design) – die Datei-basierte
    // Variante hatte das Foto nicht zuverlässig bis zur Extension durchgereicht.
    // Ein komprimiertes 800px-JPEG (siehe UIImage.resizedForWidgetBackground) ist klein
    // genug (typischerweise < 200 KB), um problemlos in UserDefaults zu landen.

    func hasCustomBackgroundImage() -> Bool {
        defaults.data(forKey: Keys.widgetBackgroundImageData) != nil
    }

    /// Schreibt bereits komprimierte JPEG-Daten in die geteilten UserDefaults.
    /// Die Größenreduktion passiert bewusst VOR diesem Aufruf (siehe
    /// UIImage.resizedForWidgetBackground), da Widget-Extensions ein sehr
    /// knappes Speicherbudget haben und ein unkomprimiertes Foto sie zum
    /// Absturz bringen könnte.
    func saveWidgetBackgroundImage(data: Data) {
        defaults.set(data, forKey: Keys.widgetBackgroundImageData)
    }

    func loadWidgetBackgroundImage() -> UIImage? {
        guard let data = defaults.data(forKey: Keys.widgetBackgroundImageData) else { return nil }
        return UIImage(data: data)
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

    /// Einfacher, deterministischer FNV-1a-Hash – im Gegensatz zu String.hashValue
    /// über Prozessstarts und Prozesse (App vs. Widget-Extension) hinweg stabil.
    /// Swifts eingebauter hashValue wird pro Prozessstart zufällig neu "gesalzen"
    /// (Sicherheitsfeature gegen Hash-Flooding) – für eine deterministische
    /// Spruchauswahl (siehe quote(for:allowedCategories:) unten) ist er deshalb ungeeignet.
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// Spruch für ein bestimmtes Datum, eingeschränkt auf erlaubte Kategorien.
    /// Ist ".custom" ("Eigene") mit erlaubt, fließen die eigenen Sprüche mit in
    /// den Auswahl-Pool ein (siehe QuoteCategory.custom).
    func quote(for date: Date, allowedCategories: Set<QuoteCategory>) -> Quote? {
        let key = Quote.dateKey(for: date)
        var all = loadAllQuotes()
        if allowedCategories.contains(.custom) {
            all += customQuotes
        }

        if let exact = all.first(where: { $0.dateKey == key && allowedCategories.contains($0.category) }) {
            return exact
        }

        // Kein exakt für diesen Tag vorgenerierter Spruch vorhanden (z.B. Pipeline noch nicht
        // gelaufen) -> deterministische Auswahl aus dem Pool, damit das Widget nie leer bleibt.
        let pool = all.filter { allowedCategories.contains($0.category) }
        guard !pool.isEmpty else { return nil }
        // Stabiler, selbst berechneter Hash statt String.hashValue (siehe stableHash):
        // sonst könnten App und Widget (getrennte Prozesse) unterschiedliche Sprüche
        // zeigen, und der gezeigte Spruch könnte sich bei jedem Neustart ändern.
        let index = Int(Self.stableHash(key) % UInt64(pool.count))
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
