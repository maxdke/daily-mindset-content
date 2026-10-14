import UIKit

extension UIImage {
    /// Verkleinert ein Bild auf eine maximale Kantenlänge, bevor es in den
    /// App-Group-Container geschrieben wird. Wichtig: Widget-Extensions haben
    /// ein sehr knappes Speicherbudget (iOS killt sie bei Überschreitung) –
    /// ein Foto direkt aus der Fotobibliothek in voller Auflösung würde das
    /// Widget zuverlässig zum Absturz bringen.
    func resizedForWidgetBackground(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
