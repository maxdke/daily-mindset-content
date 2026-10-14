import SwiftUI
import WidgetKit

@main
struct DailyMindsetApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var iconManager = IconManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .environmentObject(notificationManager)
                .environmentObject(iconManager)
                .task {
                    // Beim App-Start: frische Sprüche holen (falls fällig) und
                    // das Widget direkt informieren, damit es nicht auf den
                    // nächsten OS-gesteuerten Reload warten muss.
                    if await RemoteQuoteService.refreshIfNeeded() {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    BackgroundRefreshManager.scheduleNextRefresh()
                    await notificationManager.refreshAuthorizationStatus()
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) {
            await BackgroundRefreshManager.handleRefresh()
        }
    }
}
