import Foundation
import BackgroundTasks
import UserNotifications
import WidgetKit

/// Plant periodische Background-App-Refreshes, damit RemoteQuoteService
/// auch ohne App-Öffnung neue (KI-generierte) Sprüche nachlädt und die
/// Widget-Timeline aktualisiert. iOS entscheidet selbst, wie oft das
/// Budget dafür tatsächlich gewährt wird (i.d.R. alle paar Stunden).
enum BackgroundRefreshManager {
    static let taskIdentifier = "com.maxdeike.dailymindset.refresh"

    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Frühestens in 6 Stunden erneut versuchen.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Auf dem Simulator normal, dass das fehlschlägt — kein Problem.
            print("Konnte Background-Refresh nicht planen: \(error)")
        }
    }

    /// In der App als .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) verwenden.
    static func handleRefresh() async {
        scheduleNextRefresh() // gleich den nächsten Lauf nachplanen
        _ = await RemoteQuoteService.forceRefresh()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Verwaltet die optionale tägliche Erinnerungs-Push ("Dein Spruch für heute ist da").
/// Bewusst NICHT im App-Group-Container gespeichert: reine Geräte-/App-Einstellung,
/// die weder das Widget noch eine andere Extension braucht.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private enum Keys {
        static let enabled = "reminderNotificationsEnabled"
        static let hour = "reminderNotificationHour"
        static let minute = "reminderNotificationMinute"
    }

    private static let requestIdentifier = "com.maxdeike.dailymindset.dailyReminder"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var reminderTime: Date

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Keys.enabled)
        let hour = (defaults.object(forKey: Keys.hour) as? Int) ?? 9
        let minute = (defaults.object(forKey: Keys.minute) as? Int) ?? 0
        reminderTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// Nutzer schaltet die Erinnerung ein: fragt (falls nötig) um Systemerlaubnis
    /// und plant erst danach die tägliche Benachrichtigung.
    func enable(at time: Date) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Keys.enabled)
            return
        }
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Keys.enabled)
        await updateTime(time)
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.enabled)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }

    /// Ändert die Uhrzeit einer (ggf. bereits aktiven) Erinnerung und plant neu.
    func updateTime(_ time: Date) async {
        reminderTime = time
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        UserDefaults.standard.set(comps.hour, forKey: Keys.hour)
        UserDefaults.standard.set(comps.minute, forKey: Keys.minute)
        guard isEnabled else { return }
        await schedule(hour: comps.hour ?? 9, minute: comps.minute ?? 0)
    }

    private func schedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Daily Mindset"
        content.body = "Dein Spruch für heute ist da 💭"
        content.sound = .default

        var triggerDate = DateComponents()
        triggerDate.hour = hour
        triggerDate.minute = minute
        // repeats: true -> iOS feuert das jeden Tag zu dieser Uhrzeit von selbst,
        // ganz ohne dass die App dafür laufen oder neu planen muss.
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: Self.requestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Beim App-Start aufrufen: Falls die Erinnerung aktiviert war, die Berechtigung
    /// aber zwischenzeitlich in den iOS-Einstellungen entzogen wurde, soll der
    /// Schalter in der App das ehrlich widerspiegeln statt stillschweigend leerzulaufen.
    func refreshAuthorizationStatus() async {
        guard isEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus != .authorized {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Keys.enabled)
        }
    }
}
