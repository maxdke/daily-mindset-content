import SwiftUI

/// Kleine Bildergalerie mit den 6 kuratierten Hintergründen einer Kategorie
/// (siehe CategoryBackground) – öffnet sich beim Antippen einer Kategorie in
/// ContentView.categoryPicker. Premium-Feature, wie das bisherige eigene Foto
/// als Widget-Hintergrund: ein Tap auf ein Bild läuft durch exakt dieselbe
/// Pipeline (AppViewModel.saveCustomBackground), es gibt also keine separate
/// Speicher- oder Render-Logik nur für diese kuratierten Bilder.
struct CategoryBackgroundGalleryView: View {
    let category: QuoteCategory
    @ObservedObject var viewModel: AppViewModel
    let isPremium: Bool

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CategoryBackground.imageNames(for: category), id: \.self) { name in
                        if let uiImage = CategoryBackground.image(named: name) {
                            Button {
                                applyBackground(uiImage)
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 140)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(category.displayName)-Hintergrund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    /// Komprimiert wie beim eigenen Foto erst hier grob, dann nochmal in
    /// AppViewModel.saveCustomBackground (auf 400px) – bewusst dieselbe
    /// Pipeline wie bei einem aus der Fotobibliothek gewählten Bild, damit
    /// Widget und Teilen-Bild garantiert identisch aussehen.
    private func applyBackground(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        viewModel.saveCustomBackground(data: data, isPremium: isPremium)
        dismiss()
    }
}
