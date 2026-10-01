import Foundation

/// Kategorien, an deiner @vacdump-Nische orientiert (Finance/Productivity/Mindset).
/// Free-Nutzer bekommen nur `.mindset`, Premium schaltet alle frei.
enum QuoteCategory: String, CaseIterable, Codable, Identifiable {
    case mindset
    case business
    case discipline
    case fitness
    case gratitude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mindset: return "Mindset"
        case .business: return "Business"
        case .discipline: return "Disziplin"
        case .fitness: return "Fitness"
        case .gratitude: return "Dankbarkeit"
        }
    }

    var symbolName: String {
        switch self {
        case .mindset: return "brain.head.profile"
        case .business: return "chart.line.uptrend.xyaxis"
        case .discipline: return "flame.fill"
        case .fitness: return "figure.run"
        case .gratitude: return "heart.fill"
        }
    }

    /// Im Free-Tier verfügbare Kategorien.
    static var freeCategories: [QuoteCategory] { [.mindset] }
}
