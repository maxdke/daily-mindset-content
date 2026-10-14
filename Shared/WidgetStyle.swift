import SwiftUI

/// Auswählbares Widget-Design (Premium-Feature). Wird im App-Group-Container
/// gespeichert (siehe QuoteStore.selectedWidgetStyle), damit die Widget-Extension
/// beim nächsten Timeline-Reload den richtigen Look zieht.
///
/// Hinweis zu .photo: dessen tatsächliches Aussehen (eigenes Foto) wird NICHT über
/// `backgroundColors` gerendert, sondern direkt in MindsetWidgetEntryView per switch
/// gebaut. `backgroundColors` liefert für diesen Fall nur einen harmlosen Platzhalter-
/// Wert, falls er irgendwo generisch referenziert wird (z.B. ältere Call-Sites).
enum WidgetStyle: String, CaseIterable, Codable, Identifiable {
    case classic
    case mono
    case gold
    case light
    case photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .mono: return "Mono"
        case .gold: return "Gold"
        case .light: return "Light"
        case .photo: return "Foto"
        }
    }

    /// Hintergrund-Gradient für Homescreen-Widgets (klein/mittel) – gilt nur für
    /// classic/mono/gold/light. photo hat ein eigenes Rendering.
    var backgroundColors: [Color] {
        switch self {
        case .classic:
            return [.indigo, .black]
        case .mono:
            return [Color(white: 0.08), .black]
        case .gold:
            return [.black, Color(red: 0.22, green: 0.17, blue: 0.07)]
        case .light:
            return [Color(white: 0.98), Color(white: 0.88)]
        case .photo:
            return [.black, .black]
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .light: return .black
        default: return .white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: return .black.opacity(0.55)
        case .photo: return .white.opacity(0.8)
        default: return .white.opacity(0.65)
        }
    }

    /// Akzentfarbe für das Kategorie-Label etc.
    var accentTextColor: Color {
        switch self {
        case .gold: return Color(red: 0.80, green: 0.65, blue: 0.35)
        case .light: return Color(red: 0.70, green: 0.55, blue: 0.28)
        case .photo: return Color(red: 0.95, green: 0.84, blue: 0.60)
        default: return secondaryTextColor
        }
    }

    /// Variante von primaryTextColor, die – falls der Nutzer eine eigene Textfarbe
    /// gewählt hat (siehe QuoteStore.customTextColor) – diese statt des festen
    /// Farbschemas nutzt. nil (noch keine eigene Farbe gewählt) lässt das jeweilige
    /// Design-Farbschema unverändert. Bei .photo ist eine eigene Farbe besonders
    /// wichtig, da ein festes Weiß auf hellen eigenen Fotos schlecht lesbar sein kann,
    /// wirkt inzwischen aber bei jedem Design, falls gesetzt.
    func primaryTextColor(customTextColor: Color?) -> Color {
        customTextColor ?? primaryTextColor
    }

    /// Analog zu primaryTextColor(customTextColor:), für Autor-/Fußzeilen-Text.
    func secondaryTextColor(customTextColor: Color?) -> Color {
        guard let customTextColor else { return secondaryTextColor }
        return customTextColor.opacity(0.75)
    }
}
