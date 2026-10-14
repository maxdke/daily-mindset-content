import SwiftUI
import WidgetKit

@main
struct DailyMindsetApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var iconManager = IconManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
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

/// Wird beim App-Start statt direkt ContentView angezeigt: blendet kurz ein kleines
/// animiertes Logo auf dunklem "Aurora Dark"-Hintergrund ein (passend zum Look der
/// Hauptseite), bevor zur eigentlichen App übergeblendet wird. ContentView wird dabei
/// schon im Hintergrund geladen, damit der Übergang nahtlos wirkt statt kurz weiß
/// aufzublitzen.
private struct RootView: View {
    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                splashView
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
                textOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showSplash = false
                }
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 78, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.25), radius: 30, y: 10)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("Daily Mindset")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
            }
        }
    }
}
