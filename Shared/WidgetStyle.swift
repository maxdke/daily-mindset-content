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
    case noir
    case neon
    case sunrise
    case forest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .mono: return "Mono"
        case .gold: return "Gold"
        case .light: return "Light"
        case .photo: return "Foto"
        case .noir: return "Noir"
        case .neon: return "Neon Glow"
        case .sunrise: return "Sunrise"
        case .forest: return "Forest Calm"
        }
    }

    /// Hintergrund-Gradient für Homescreen-Widgets (klein/mittel) – gilt nur für
    /// classic/mono/gold/light/noir/neon/sunrise/forest. photo hat ein eigenes Rendering.
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
        case .noir:
            // Fast reines Schwarz, bewusst flach/ohne auffälligen Verlauf – passend
            // zum "Noir Editorial"-Look der App.
            return [Color(white: 0.04), .black]
        case .neon:
            // Flaches Schwarz als Bühne für den leuchtenden Rand (siehe
            // MindsetWidgetEntryView.neonGlowOverlay) statt eines Verlaufs.
            return [.black, .black]
        case .sunrise:
            return [Color(red: 1.0, green: 0.494, blue: 0.373), Color(red: 0.996, green: 0.706, blue: 0.482)]
        case .forest:
            return [Color(red: 0.102, green: 0.337, blue: 0.325), Color(red: 0.059, green: 0.239, blue: 0.243)]
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .light: return .black
        case .forest: return Color(red: 0.957, green: 0.973, blue: 0.961)
        default: return .white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: return .black.opacity(0.55)
        case .photo: return .white.opacity(0.8)
        case .sunrise: return .white.opacity(0.85)
        case .forest: return Color(red: 0.749, green: 0.902, blue: 0.812).opacity(0.85)
        default: return .white.opacity(0.65)
        }
    }

    /// Akzentfarbe für das Kategorie-Label etc.
    var accentTextColor: Color {
        switch self {
        case .gold: return Color(red: 0.80, green: 0.65, blue: 0.35)
        case .light: return Color(red: 0.70, green: 0.55, blue: 0.28)
        case .photo: return Color(red: 0.95, green: 0.84, blue: 0.60)
        case .neon: return Color(red: 0.31, green: 0.90, blue: 1.0)
        case .forest: return Color(red: 0.749, green: 0.902, blue: 0.812)
        case .sunrise: return .white.opacity(0.85)
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
