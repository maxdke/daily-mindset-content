import Foundation
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var todaysQuote: Quote?
    @Published private(set) var selectedCategories: Set<QuoteCategory>
    @Published private(set) var selectedWidgetStyle: WidgetStyle
    @Published private(set) var customTextColor: Color?
    @Published private(set) var quoteFont: QuoteFont
    @Published private(set) var glowBorderEnabled: Bool
    @Published private(set) var glowBorderColor: Color
    @Published private(set) var hasCustomBackground: Bool
    @Published private(set) var customBackgroundThumbnail: UIImage?
    @Published private(set) var favoriteQuoteIDs: Set<String>
    @Published private(set) var pinnedQuoteID: String?
    @Published private(set) var currentStreak: Int
    @Published private(set) var customQuotes: [Quote]
    @Published private(set) var reflections: [Reflection]

    private let store = QuoteStore.shared

    init() {
        selectedCategories = store.selectedCategories
        selectedWidgetStyle = store.selectedWidgetStyle
        customTextColor = store.customTextColor
        quoteFont = store.quoteFont
        glowBorderEnabled = store.glowBorderEnabled
        glowBorderColor = store.glowBorderColor
        hasCustomBackground = store.hasCustomBackgroundImage()
        customBackgroundThumbnail = store.loadWidgetBackgroundImage()
        favoriteQuoteIDs = store.favoriteQuoteIDs
        pinnedQuoteID = store.pinnedQuoteID
        currentStreak = store.currentStreak
        customQuotes = store.customQuotes
        reflections = store.reflections
    }

    /// Beim App-Start aufzurufen (siehe ContentView). Kostenloses Feature für
    /// alle Nutzer – motiviert zur täglichen Rückkehr, unabhängig vom Abo-Status.
    func recordDailyOpen() {
        currentStreak = store.recordAppOpenForStreak()
    }

    /// Eigene Sprüche (kostenloses Feature, siehe FavoritesView-Tab "Eigene"): das
    /// Schreiben selbst ist kein Premium-Gate. Ist "Eigene" aber als Kategorie aktiv
    /// (Premium, siehe QuoteCategory.custom), soll der Tagesspruch/das Widget sofort
    /// reagieren, statt erst beim nächsten App-Start/Kategorie-Wechsel.
    @discardableResult
    func addCustomQuote(text: String, author: String?, isPremium: Bool) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        _ = store.addCustomQuote(text: text, author: author)
        customQuotes = store.customQuotes
        if selectedCategories.contains(.custom) {
            refreshTodaysQuote(isPremium: isPremium)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return true
    }

    func deleteCustomQuote(_ quote: Quote, isPremium: Bool) {
        store.deleteCustomQuote(id: quote.id)
        customQuotes = store.customQuotes
        favoriteQuoteIDs = store.favoriteQuoteIDs
        var shouldReloadWidget = false
        if pinnedQuoteID == quote.id {
            pinnedQuoteID = nil
            shouldReloadWidget = true
        }
        if selectedCategories.contains(.custom) {
            refreshTodaysQuote(isPremium: isPremium)
            shouldReloadWidget = true
        }
        if shouldReloadWidget {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Speichert (oder aktualisiert) die kurze eigene Notiz zum übergebenen Spruch
    /// (siehe ContentView.reflectionPrompt). Kostenloses Feature wie "Eigene
    /// Sprüche" – kein Premium-Gate, soll zum täglichen Zurückkommen motivieren.
    @discardableResult
    func saveReflection(text: String, for quote: Quote) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        _ = store.addOrUpdateReflection(for: quote, text: text)
        reflections = store.reflections
        return true
    }

    func deleteReflection(_ reflection: Reflection) {
        store.deleteReflection(id: reflection.id)
        reflections = store.reflections
    }

    /// Bereits gespeicherte Notiz zu einer bestimmten quoteID, falls vorhanden –
    /// damit das Eingabefeld beim Durchswipen/erneuten Öffnen vorausgefüllt ist.
    func reflection(forQuoteID quoteID: String) -> Reflection? {
        reflections.first { $0.quoteID == quoteID }
    }

    func refreshTodaysQuote(isPremium: Bool) {
        let allowed = isPremium ? selectedCategories : Set(QuoteCategory.freeCategories)
        todaysQuote = store.quote(for: Date(), allowedCategories: allowed)
    }

    /// Es lässt sich immer nur genau eine Kategorie auswählen (Radio-Verhalten, kein
    /// Mehrfach-Toggle mehr): Tages-/Widget-Spruch kommt ohnehin nur aus einer einzigen
    /// Kategorie, mehrere gleichzeitig "ausgewählt" zu haben wirkte nur so, als würden
    /// alle einfließen, obwohl de facto zufällig nur noch zwischen ihnen gemischt wurde.
    /// Tippen auf die bereits gewählte Kategorie ist ein No-Op, nicht deaktivierbar
    /// (siehe WidgetCenter.reloadAllTimelines unten).
    func selectCategory(_ category: QuoteCategory, isPremium: Bool) {
        guard isPremium else { return }
        guard selectedCategories != [category] else { return }
        selectedCategories = [category]
        store.selectedCategories = selectedCategories
        refreshTodaysQuote(isPremium: isPremium)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Premium-Feature: Widget-Design wechseln. Schreibt in den App-Group-Container
    /// und stößt direkt ein Timeline-Reload an, damit das Widget sofort den neuen
    /// Look zeigt, statt auf den nächsten OS-gesteuerten Refresh zu warten.
    func setWidgetStyle(_ style: WidgetStyle, isPremium: Bool) {
        guard isPremium else { return }
        selectedWidgetStyle = style
        store.selectedWidgetStyle = style
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Premium-Feature: eigene Textfarbe fürs Widget + Teilen-Bild (siehe
    /// WidgetStyle.primaryTextColor(customTextColor:)) – wirkt global, bei jedem
    /// Widget-Design, bis sie zurückgesetzt wird (siehe resetCustomTextColor).
    /// Stößt wie setWidgetStyle direkt ein Timeline-Reload an, damit Widget und
    /// Teilen-Bild sofort den neuen Farbton zeigen.
    func setCustomTextColor(_ color: Color, isPremium: Bool) {
        guard isPremium else { return }
        customTextColor = color
        store.customTextColor = color
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Setzt die Textfarbe zurück auf das feste Farbschema des jeweiligen
    /// Widget-Designs (siehe WidgetStyle.primaryTextColor/secondaryTextColor).
    func resetCustomTextColor(isPremium: Bool) {
        guard isPremium else { return }
        customTextColor = nil
        store.customTextColor = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Premium-Feature: eigene Schriftart für den Spruchtext (siehe QuoteFont) – wirkt
    /// global, unabhängig vom gewählten Widget-Design, genau wie customTextColor.
    /// Stößt wie setWidgetStyle direkt ein Timeline-Reload an, damit Widget und
    /// Teilen-Bild sofort die neue Schrift zeigen.
    func setQuoteFont(_ font: QuoteFont, isPremium: Bool) {
        guard isPremium else { return }
        quoteFont = font
        store.quoteFont = font
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Premium-Feature: leuchtender Rand ums Widget an-/ausschalten (siehe
    /// QuoteStore.glowBorderEnabled) – unabhängig vom gewählten Widget-Design.
    func setGlowBorderEnabled(_ enabled: Bool, isPremium: Bool) {
        guard isPremium else { return }
        glowBorderEnabled = enabled
        store.glowBorderEnabled = enabled
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Premium-Feature: Farbe des leuchtenden Rands (siehe QuoteStore.glowBorderColor).
    func setGlowBorderColor(_ color: Color, isPremium: Bool) {
        guard isPremium else { return }
        glowBorderColor = color
        store.glowBorderColor = color
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Favoriten sind bewusst KEIN Premium-Feature (anders als Kategorien/Widget-Design):
    /// ein einfacher, kostenloser Mehrwert, der Nutzer täglich zurückbringt.
    func isFavorite(_ quote: Quote) -> Bool {
        favoriteQuoteIDs.contains(quote.id)
    }

    func toggleFavorite(_ quote: Quote) {
        store.toggleFavorite(quote)
        favoriteQuoteIDs = store.favoriteQuoteIDs
    }

    var favoriteQuotes: [Quote] {
        store.favoriteQuotes()
    }

    /// Angehefteter Spruch, falls einer gesetzt ist (überschreibt im Widget die
    /// automatische Tagesrotation, bis der Nutzer ihn wieder löst).
    var pinnedQuote: Quote? {
        store.pinnedQuote()
    }

    /// Alle Sprüche, die der Nutzer schon zu sehen bekommen hat, in aktuell
    /// erlaubten Kategorien – Grundlage für die manuelle Widget-Auswahl.
    func appearedQuotes(isPremium: Bool) -> [Quote] {
        let allowed = isPremium ? selectedCategories : Set(QuoteCategory.freeCategories)
        return store.appearedQuotes(allowedCategories: allowed)
    }

    /// Heftet einen Spruch fürs Widget an (Premium-Feature, wie Widget-Design/Kategorien).
    func pinQuote(_ quote: Quote, isPremium: Bool) {
        guard isPremium else { return }
        store.pinnedQuoteID = quote.id
        pinnedQuoteID = quote.id
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Löst die Anheftung – das Widget zeigt wieder den automatisch rotierenden Tagesspruch.
    func unpinQuote() {
        store.pinnedQuoteID = nil
        pinnedQuoteID = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Speichert ein vom Nutzer gewähltes Foto als Widget-Hintergrund (Premium-Feature)
    /// und schaltet direkt auf den "Foto"-Stil um. Das Bild bleibt ausschließlich lokal
    /// im App-Group-Container – es wird nirgendwo hochgeladen.
    func saveCustomBackground(data: Data, isPremium: Bool) {
        guard isPremium, let uiImage = UIImage(data: data) else { return }
        // Reduziert auf 400px: Widget-Extensions haben ein sehr knappes Speicherbudget,
        // und ein zu großes Bild kann die Extension beim Dekodieren zum Absturz bringen
        // (WidgetKit zeigt dann stillschweigend nur den letzten funktionierenden Stand).
        let resized = uiImage.resizedForWidgetBackground(maxDimension: 400)
        guard let jpegData = resized.jpegData(compressionQuality: 0.6) else { return }
        store.saveWidgetBackgroundImage(data: jpegData)
        hasCustomBackground = true
        customBackgroundThumbnail = resized
        setWidgetStyle(.photo, isPremium: isPremium)
    }
}
