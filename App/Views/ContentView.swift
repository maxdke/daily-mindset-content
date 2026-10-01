import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = AppViewModel()
    @State private var showPaywall = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    quoteCard
                    categoryPicker
                    widgetInstructions
                }
                .padding()
            }
            .navigationTitle("Daily Mindset")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task(id: subscriptionManager.isPremium) {
                viewModel.refreshTodaysQuote(isPremium: subscriptionManager.isPremium)
            }
        }
    }

    private var quoteCard: some View {
        VStack(spacing: 12) {
            if let quote = viewModel.todaysQuote {
                Text(quote.category.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(quote.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                if let author = quote.author {
                    Text("– \(author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kategorien")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(QuoteCategory.allCases) { category in
                let isFree = QuoteCategory.freeCategories.contains(category)
                let isSelected = viewModel.selectedCategories.contains(category)
                let isLocked = !subscriptionManager.isPremium && !isFree

                Button {
                    if isLocked {
                        showPaywall = true
                    } else {
                        viewModel.toggleCategory(category, isPremium: subscriptionManager.isPremium)
                    }
                } label: {
                    HStack {
                        Image(systemName: category.symbolName)
                        Text(category.displayName)
                        Spacer()
                        if isLocked {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                        } else if isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                Divider()
            }
        }
    }

    private var widgetInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Widget hinzufügen", systemImage: "square.grid.2x2")
                .font(.headline)
            Text("Homescreen gedrückt halten → „+“ oben links → „Daily Mindset“ suchen → Größe wählen → Hinzufügen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionManager.shared)
}
