import SwiftUI

/// Frei wählbare Schriftart für den Spruchtext – Premium-Feature, analog zu
/// Widget-Design/Textfarbe (siehe AppViewModel.setQuoteFont, QuoteStore.quoteFont).
/// Wirkt global überall dort, wo der eigentliche Spruchtext gerendert wird
/// (Hauptkarte, Teilen-Bild, Widget), unabhängig vom gewählten Widget-Design –
/// genau wie customTextColor, die ebenfalls global über alle Widget-Designs wirkt.
enum QuoteFont: String, CaseIterable, Codable, Identifiable {
    case standard
    case rounded
    case serif
    case elegant
    case playful
    case modern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .rounded: return "Rund"
        case .serif: return "Serif"
        case .elegant: return "Elegant"
        case .playful: return "Verspielt"
        case .modern: return "Modern"
        }
    }

    /// Für dynamische Textgrößen (Hauptkarte): skaliert mit der System-Schriftgröße
    /// des Nutzers (Barrierefreiheit), genau wie der bisherige feste ".title2"/
    /// ".subheadline"-Stil, den diese Funktion ersetzt.
    func font(textStyle: Font.TextStyle, size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch self {
        case .standard:
            return .system(textStyle, design: .default).weight(weight)
        case .rounded:
            return .system(textStyle, design: .rounded).weight(weight)
        case .serif:
            return .system(textStyle, design: .serif).weight(weight)
        case .elegant:
            return .custom(FontName.elegant, size: size, relativeTo: textStyle)
        case .playful:
            return .custom(FontName.playful, size: size, relativeTo: textStyle)
        case .modern:
            return .custom(FontName.modern, size: size, relativeTo: textStyle)
        }
    }

    /// Für fest dimensionierte Kontexte ohne Dynamic Type (Teilen-Bild als
    /// gerendertes Bild, Widget-Text in fixer Punktgröße).
    func font(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch self {
        case .standard:
            return .system(size: size, weight: weight, design: .default)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .elegant:
            return .custom(FontName.elegant, size: size)
        case .playful:
            return .custom(FontName.playful, size: size)
        case .modern:
            return .custom(FontName.modern, size: size)
        }
    }

    /// PostScript-Namen fest in iOS eingebauter System-Schriften (keine eigenen
    /// Font-Dateien nötig, dadurch auch keine Lizenzfragen/Bundle-Größe-Thema).
    private enum FontName {
        static let elegant = "SnellRoundhand-Bold"
        static let playful = "Noteworthy-Bold"
        static let modern = "Futura-Medium"
    }
}
