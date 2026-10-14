import Foundation

/// Ein einzelner Spruch. `id` ist deterministisch (category+date+index),
/// damit Widget-Timeline und App denselben Eintrag referenzieren können.
struct Quote: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let author: String?
    let category: QuoteCategory
    /// Tag, für den der Spruch vorgesehen ist (yyyy-MM-dd), zur Rotation.
    let dateKey: String

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

/// Container-Format für quotes.json (sowohl gebündeltes Seed-File
/// als auch die vom Content-Pipeline-Skript nachgelieferte Datei).
struct QuoteBatch: Codable {
    let generatedAt: String
    let quotes: [Quote]
}

/// Ein einzelner Reflexions-Eintrag: die kurze eigene Notiz, die der Nutzer
/// optional zum gerade angezeigten Spruch schreiben kann (siehe
/// ContentView.reflectionPrompt / ReflectionHistoryView). Spruchtext/-autor
/// werden bewusst mitgespeichert (nicht nur die quoteID), damit der Verlauf
/// auch dann noch den dazugehörigen Spruch zeigt, wenn der Spruch selbst
/// später nicht mehr in der Rotation auftaucht (z.B. nach einem Remote-Fetch).
struct Reflection: Codable, Identifiable, Hashable {
    let id: String
    let quoteID: String
    let quoteText: String
    let quoteAuthor: String?
    var text: String
    let dateKey: String
    let createdAt: Date
}
