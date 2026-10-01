import Foundation

/// Zentrale Konstanten für den geteilten Speicher zwischen App und Widget.
/// WICHTIG: Diese App-Group-ID muss in beiden Entitlements-Dateien
/// UND im Apple Developer Portal (App Groups Capability) identisch hinterlegt sein.
enum AppGroup {
    static let identifier = "group.com.maxdeike.dailymindset"

    static var sharedDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            fatalError("App Group '\(identifier)' ist nicht korrekt konfiguriert.")
        }
        return defaults
    }

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
