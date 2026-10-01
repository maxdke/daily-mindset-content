import Foundation
import BackgroundTasks
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
