import AppIntents
import WidgetKit

/// Interaktiver Widget-Button "Neuer Spruch" (siehe MindsetWidgetEntryView) – läuft
/// direkt im Widget-Prozess (App Intents, iOS 17+), OHNE die App zu öffnen. Schaltet
/// den aktuell angezeigten Spruch auf den nächsten aus der Browsing-Liste
/// (QuoteStore.appearedQuotes) weiter, siehe QuoteStore.advanceWidgetOverride.
/// Kostenloses Feature (wie das Durchblättern in der App selbst) – ist ein Spruch
/// explizit angeheftet (Premium, siehe QuoteStore.pinnedQuoteID), bleibt der Button
/// bewusst wirkungslos, da Pin ausdrücklich genau DIESEN einen Spruch festhalten soll
/// (der Button wird in diesem Fall in der Widget-Ansicht ohnehin ausgeblendet).
struct NextQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Neuer Spruch"
    static var description = IntentDescription("Zeigt einen anderen Spruch im Widget, ohne die App zu öffnen.")

    func perform() async throws -> some IntentResult {
        let store = QuoteStore.shared
        guard store.pinnedQuoteID == nil else {
            return .result()
        }
        store.advanceWidgetOverride(allowedCategories: store.allowedCategoriesNow)
        WidgetCenter.shared.reloadTimelines(ofKind: "MindsetWidget")
        return .result()
    }
}
