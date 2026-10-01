import SwiftUI
import WidgetKit

@main
struct DailyMindsetApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .task {
                    // Beim App-Start: frische Sprüche holen (falls fällig) und
                    // das Widget direkt informieren, damit es nicht auf den
                    // nächsten OS-gesteuerten Reload warten muss.
                    if await RemoteQuoteService.refreshIfNeeded() {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    BackgroundRefreshManager.scheduleNextRefresh()
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) {
            await BackgroundRefreshManager.handleRefresh()
        }
    }
}
