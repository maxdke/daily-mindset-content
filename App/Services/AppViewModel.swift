import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var todaysQuote: Quote?
    @Published private(set) var selectedCategories: Set<QuoteCategory>

    private let store = QuoteStore.shared

    init() {
        selectedCategories = store.selectedCategories
    }

    func refreshTodaysQuote(isPremium: Bool) {
        let allowed = isPremium ? selectedCategories : Set(QuoteCategory.freeCategories)
        todaysQuote = store.quote(for: Date(), allowedCategories: allowed)
    }

    func toggleCategory(_ category: QuoteCategory, isPremium: Bool) {
        guard isPremium else { return }
        if selectedCategories.contains(category) {
            if selectedCategories.count > 1 {
                selectedCategories.remove(category)
            }
        } else {
            selectedCategories.insert(category)
        }
        store.selectedCategories = selectedCategories
        refreshTodaysQuote(isPremium: isPremium)
    }
}
