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
    /// Zeigt den 3-Screen-Einstieg (Widget-Anleitung + Erinnerungs-Erlaubnis) nur beim
    /// allerersten Start; danach merkt sich UserDefaults, dass er schon lief.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingFlowView {
                        hasCompletedOnboarding = true
                    }
                }
            }
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


/// Hauptnavigation der App (Max' Wunsch): eine Tab-Leiste mit vier Bereichen,
/// damit die wachsende Zahl an Design-Optionen nicht mehr alle auf der Hauptseite
/// liegen. Der AppViewModel-Store wird hier EINMAL erzeugt und an jeden Tab
/// weitergereicht, damit z.B. eine neue Reflexion oder ein Design-Wechsel überall
/// sofort konsistent ankommt.
private struct RootTabView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView {
            ContentView(viewModel: viewModel)
                .tabItem { Label("Heute", systemImage: "house") }
            DesignView(viewModel: viewModel)
                .tabItem { Label("Design", systemImage: "paintpalette") }
            ReflectionHistoryView(viewModel: viewModel)
                .tabItem { Label("Reflexionen", systemImage: "text.book.closed") }
            SettingsView(viewModel: viewModel)
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
        }
        .preferredColorScheme(.dark)
    }
}


/// Kurzer 3-Screen-Einstieg beim allerersten App-Start (siehe hasCompletedOnboarding
/// in RootView): erklärt kurz den Sinn der App, leitet dann zur Widget-Aktivierung an
/// (der wichtigste tägliche Rückkehr-Grund) und fragt erst danach, mit Kontext statt
/// nacktem System-Dialog, nach der Erinnerungs-Erlaubnis. Läuft nur einmal.
private struct OnboardingFlowView: View {
    @EnvironmentObject private var iconManager: IconManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var step = 0
    let onFinished: () -> Void

    private var background: Color {
        Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: widgetStep
                default: notificationStep
                }
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == step ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                        .shadow(color: .white.opacity(index == step ? 0.6 : 0), radius: 8)
                }
            }
            .padding(.bottom, 22)

            if step < 2 {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    Text("WEITER")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .foregroundStyle(.white)
                .overlay(Capsule().strokeBorder(Color.white, lineWidth: 1.5))
                .padding(.horizontal, 26)
                .padding(.bottom, 46)
            } else {
                VStack(spacing: 14) {
                    Button {
                        Task {
                            await notificationManager.enable(at: notificationManager.reminderTime)
                            onFinished()
                        }
                    } label: {
                        Text("ERLAUBEN")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    }
                    .foregroundStyle(background)
                    .background(Capsule().fill(Color.white))
                    .padding(.horizontal, 26)

                    Button("Vielleicht später", action: onFinished)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Image(iconManager.currentIcon.previewImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary, lineWidth: 1.5)
                )
                .shadow(color: Color.primary.opacity(0.4), radius: 20)
                .padding(.bottom, 28)

            Text("DAILY MINDSET")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)

            Text("Dein täglicher Impuls,\ndirekt auf dem Homescreen.")
                .font(.system(size: 23, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("Ein neuer Spruch pro Tag, als Widget immer sichtbar – kein Feed, kein Scrollen, nur ein Gedanke, der hängen bleibt.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
        }
        .padding(.horizontal, 36)
    }

    private var widgetStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("SCHRITT 2 VON 3")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(.secondary)
                Text("Aktiviere dein Widget")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("So landet dein Spruch jeden Tag direkt auf deinem Homescreen.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 28)

            VStack(spacing: 0) {
                widgetOnboardingStep(number: 1, text: "Homescreen gedrückt halten")
                widgetOnboardingStep(number: 2, text: "Oben links auf „+“ tippen")
                widgetOnboardingStep(number: 3, text: "„Daily Mindset“ suchen & Größe wählen")
                widgetOnboardingStep(number: 4, text: "Hinzufügen – fertig", showDivider: false)
            }
            .padding(.horizontal, 30)
        }
    }

    private func widgetOnboardingStep(number: Int, text: String, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                Text(text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(white: 0.9))
                Spacer()
            }
            .padding(.vertical, 13)
            if showDivider {
                Divider().overlay(Color.white.opacity(0.1))
            }
        }
    }

    private var notificationStep: some View {
        VStack(spacing: 0) {
            Image(systemName: "bell")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(Color.primary, lineWidth: 1.5))
                .shadow(color: Color.primary.opacity(0.4), radius: 20)
                .padding(.bottom, 28)

            Text("SCHRITT 3 VON 3")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)

            Text("Verpasse nie deinen Spruch")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Wir erinnern dich einmal täglich an deinen Mindset-Moment. Du kannst das jederzeit in „Mehr“ wieder ändern.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 36)
    }
}

