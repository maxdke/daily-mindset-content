import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Daily Mindset Premium")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Alle Kategorien freischalten (Business, Fitness, Disziplin, Dankbarkeit)")
                    featureRow("Täglich neue, abwechslungsreiche Sprüche")
                    featureRow("Zusätzliche Widget-Styles")
                }
                .padding(.horizontal)

                if subscriptionManager.products.isEmpty {
                    ProgressView().padding()
                } else {
                    VStack(spacing: 12) {
                        ForEach(subscriptionManager.products) { product in
                            Button {
                                Task { await subscriptionManager.purchase(product) }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    Text(product.displayPrice).fontWeight(.semibold)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.tint.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Button("Käufe wiederherstellen") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                .font(.footnote)

                if let error = subscriptionManager.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onChange(of: subscriptionManager.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
            .font(.subheadline)
    }
}

#Preview {
    PaywallView().environmentObject(SubscriptionManager.shared)
}
