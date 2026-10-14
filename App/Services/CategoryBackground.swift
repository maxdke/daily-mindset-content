import UIKit

/// Kuratierte Hintergrundbilder pro Kategorie – gebündelt als Folder Reference
/// "CategoryBackgrounds" im App-Target (siehe MindsetAssets/CategoryBackgrounds/,
/// Dateinamen bg_<QuoteCategory.rawValue>_<1...6>.jpg). Basis für die Bildergalerie,
/// die sich beim Antippen einer Kategorie öffnet (siehe
/// ContentView.categoryPicker / CategoryBackgroundGalleryView).
///
/// Wichtig: das hier ist nur der Auswahl-Pool im App-Bundle. Ausgewählt läuft ein
/// Bild durch dieselbe Pipeline wie ein selbst gewähltes Foto (siehe
/// AppViewModel.saveCustomBackground + UIImage.resizedForWidgetBackground) – es
/// gibt also keine zweite Speicher-/Render-Logik für Widget oder Teilen-Bild.
enum CategoryBackground {
    /// 6 Bildnamen (ohne Dateiendung) je Kategorie.
    static func imageNames(for category: QuoteCategory) -> [String] {
        (1...6).map { "bg_\(category.rawValue)_\($0)" }
    }

    /// Lädt ein kuratiertes Bild aus dem App-Bundle. nil, falls die Datei fehlt
    /// (z.B. falscher Name) – die Galerie blendet so ein fehlendes Bild einfach aus,
    /// statt abzustürzen.
    static func image(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "jpg",
            subdirectory: "CategoryBackgrounds"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
