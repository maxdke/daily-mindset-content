import Foundation
import StoreKit
import SwiftUI
import UIKit

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


/// Verwaltet das alternative App-Icon (Premium-Feature). Die Icons liegen als ganz
/// normale "App Icon"-Sets im Asset-Katalog (siehe App/Assets.xcassets/AppIcon-*.appiconset);
/// der Build-Setting ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS macht sie automatisch
/// als Alternate Icons verfügbar, referenziert über den Namen des jeweiligen Sets – kein
/// zusätzliches Info.plist-Setup nötig. Farben/Namen spiegeln bewusst die Widget-Designs
/// (siehe WidgetStyle), damit Icon und Widget zueinander passen können.
///
/// WICHTIG: `setAlternateIconName` löst einen System-Dialog aus ("'Daily Mindset' möchte
/// den Home-Bildschirm anpassen"), der von Apple vorgeschrieben ist und nicht übersprungen
/// werden kann – das ist normales iOS-Verhalten, kein Bug.
@MainActor
final class IconManager: ObservableObject {
    static let shared = IconManager()

    enum AppIcon: String, CaseIterable, Identifiable {
        case standard
        case mono = "AppIcon-Mono"
        case gold = "AppIcon-Gold"
        case light = "AppIcon-Light"

        var id: String { rawValue }

        /// nil = Standard-Icon – das erwartet setAlternateIconName für "zurücksetzen".
        var assetName: String? { self == .standard ? nil : rawValue }

        var displayName: String {
            switch self {
            case .standard: return "Classic"
            case .mono: return "Mono"
            case .gold: return "Gold"
            case .light: return "Light"
            }
        }

        /// Name des Vorschaubilds in den Einstellungen – bewusst das ECHTE Icon-Artwork
        /// (als eigenes Image-Set hinterlegt, siehe IconPreview-*.imageset), nicht eine
        /// Farbverlauf-Annäherung. Nur so zeigt die Auswahl exakt das, was nachher wirklich
        /// auf dem Homescreen landet – eine Annäherung ließ z.B. Classic und Mono fast
        /// gleich aussehen, obwohl die echten Icons sich deutlich unterscheiden (Glow,
        /// Helligkeit, Farbton).
        var previewImageName: String {
            switch self {
            case .standard: return "IconPreview-Classic"
            case .mono: return "IconPreview-Mono"
            case .gold: return "IconPreview-Gold"
            case .light: return "IconPreview-Light"
            }
        }
    }

    @Published private(set) var currentIcon: AppIcon

    private init() {
        let currentName = UIApplication.shared.alternateIconName
        currentIcon = AppIcon.allCases.first { $0.assetName == currentName } ?? .standard
    }

    /// Setzt das App-Icon direkt um – "lädt automatisch" bedeutet hier: kein Zwischenschritt
    /// nötig, nur die von Apple vorgeschriebene System-Bestätigung erscheint kurz.
    func setIcon(_ icon: AppIcon) {
        guard UIApplication.shared.supportsAlternateIcons, icon != currentIcon else { return }
        UIApplication.shared.setAlternateIconName(icon.assetName) { [weak self] error in
            Task { @MainActor in
                guard error == nil else { return }
                self?.currentIcon = icon
            }
        }
    }
}
