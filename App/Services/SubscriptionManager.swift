import Foundation
import StoreKit

/// StoreKit-2-Wrapper: lädt Produkte, wickelt Käufe ab, hört auf Transaction-Updates
/// und spiegelt den Premium-Status in den geteilten App-Group-Container (QuoteStore),
/// damit das Widget den aktuellen Stand kennt, ohne selbst StoreKit anzufragen.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum ProductID: String, CaseIterable {
        case monthly = "com.maxdeike.dailymindset.premium.monthly"
        case yearly = "com.maxdeike.dailymindset.premium.yearly"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = false
    @Published var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
        } catch {
            lastError = "Produkte konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Kauf fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Prüft alle aktuell gültigen Entitlements und setzt isPremium entsprechend.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProductID(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
        QuoteStore.shared.isPremium = active
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
