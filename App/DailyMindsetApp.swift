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
            LinearGradient(
                colors: [
                    Color(red: 0x12 / 255, green: 0x0C / 255, blue: 0x28 / 255),
                    Color(red: 0x0A / 255, green: 0x07 / 255, blue: 0x16 / 255),
                    Color(red: 0x03 / 255, green: 0x02 / 255, blue: 0x04 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.accentColor.opacity(0.5), radius: 24, y: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text("Daily Mindset")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
            }
        }
    }
}
