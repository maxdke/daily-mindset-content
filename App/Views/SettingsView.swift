import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Abo") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(subscriptionManager.isPremium ? "Premium aktiv" : "Free")
                            .foregroundStyle(.secondary)
                    }
                    Button("Käufe wiederherstellen") {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        Link("Abo verwalten", destination: url)
                    }
                }
                Section("Über") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionManager.shared)
}
