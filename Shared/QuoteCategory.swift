import Foundation

/// Kategorien, an deiner @vacdump-Nische orientiert (Finance/Productivity/Mindset).
/// Free-Nutzer bekommen nur `.mindset`, Premium schaltet alle frei.
enum QuoteCategory: String, CaseIterable, Codable, Identifiable {
    case mindset
    case business
    case discipline
    case fitness
    case gratitude
    /// Vom Nutzer selbst geschriebene Sprüche (siehe QuoteStore.customQuotes).
    /// Normalerweise nicht Teil der Tagesrotation, kann aber in der Kategorie-Auswahl
    /// aktiviert werden (Premium) – dann bezieht QuoteStore.quote(for:allowedCategories:)
    /// die eigenen Sprüche mit in den Auswahl-Pool ein (siehe dort).
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mindset: return "Mindset"
        case .business: return "Business"
        case .discipline: return "Disziplin"
        case .fitness: return "Fitness"
        case .gratitude: return "Dankbarkeit"
        case .custom: return "Eigene"
        }
    }

    var symbolName: String {
        switch self {
        case .mindset: return "brain.head.profile"
        case .business: return "chart.line.uptrend.xyaxis"
        case .discipline: return "flame.fill"
        case .fitness: return "figure.run"
        case .gratitude: return "heart.fill"
        case .custom: return "pencil.and.scribble"
        }
    }

    /// Im Free-Tier verfügbare Kategorien.
    static var freeCategories: [QuoteCategory] { [.mindset] }
}
