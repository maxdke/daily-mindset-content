import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var iconManager: IconManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    appIconPicker
                } header: {
                    HStack {
                        Text("App-Icon")
                        if !subscriptionManager.isPremium {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Wähle ein alternatives App-Icon passend zu deinem Widget-Design – wird sofort auf dem Homescreen übernommen.")
                }
                Section {
                    Toggle("Tägliche Erinnerung", isOn: Binding(
                        get: { notificationManager.isEnabled },
                        set: { newValue in
                            Task {
                                if newValue {
                                    await notificationManager.enable(at: notificationManager.reminderTime)
                                } else {
                                    notificationManager.disable()
                                }
                            }
                        }
                    ))
                    if notificationManager.isEnabled {
                        DatePicker(
                            "Uhrzeit",
                            selection: Binding(
                                get: { notificationManager.reminderTime },
                                set: { newTime in
                                    Task { await notificationManager.updateTime(newTime) }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Erinnerung")
                } footer: {
                    Text("Wir erinnern dich einmal täglich zur gewählten Uhrzeit an deinen Spruch des Tages.")
                }
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
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var appIconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(IconManager.AppIcon.allCases) { icon in
                    iconSwatch(icon)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .padding(.horizontal)
    }

    private func iconSwatch(_ icon: IconManager.AppIcon) -> some View {
        let isSelected = iconManager.currentIcon == icon
        // Classic/Standard ist immer frei wählbar (ist ja ohnehin das Standard-Icon) –
        // nur die zusätzlichen Designs sind Premium, analog zum Widget-Design.
        let isLocked = !subscriptionManager.isPremium && icon != .standard

        return VStack(spacing: 6) {
            Button {
                if isLocked {
                    showPaywall = true
                } else {
                    iconManager.setIcon(icon)
                }
            } label: {
                // Echtes Icon-Artwork statt Farbverlauf-Annäherung, damit die Vorschau
                // exakt zeigt, was auf dem Homescreen landet (siehe previewImageName).
                Image(icon.previewImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.55)))
                            .offset(x: 5, y: -5)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, Color.accentColor)
                            .background(Circle().fill(.white))
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(icon.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(IconManager.shared)
}
