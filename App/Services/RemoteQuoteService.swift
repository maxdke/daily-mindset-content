import Foundation

/// Lädt beim App-Start (bzw. bei Background App Refresh) eine aktuelle
/// Sprüche-Datei von deinem eigenen Endpoint und schreibt sie in den
/// App-Group-Container. Das Widget selbst ruft NIEMALS das Netzwerk auf —
/// es liest nur, was hier zuletzt im geteilten Container gespeichert wurde.
///
/// WICHTIG: Trage unten deine echte URL ein, sobald du quotes.json irgendwo
/// hostest (z.B. GitHub Pages, ein simpler S3-Bucket, eine eigene kleine API).
/// Das Format muss dem QuoteBatch-Schema entsprechen (siehe ContentPipeline/).
enum RemoteQuoteService {
    static var endpoint: URL? {
        URL(string: "https://maxdke.github.io/daily-mindset-content/ContentPipeline/quotes.json")
    }

    /// Minimaler Abstand zwischen zwei Remote-Fetches, um Kosten/Traffic gering zu halten.
    static let minimumFetchInterval: TimeInterval = 60 * 60 * 6 // 6 Stunden

    @discardableResult
    static func refreshIfNeeded() async -> Bool {
        if let last = QuoteStore.shared.lastRemoteFetch,
           Date().timeIntervalSince(last) < minimumFetchInterval {
            return false
        }
        return await forceRefresh()
    }

    @discardableResult
    static func forceRefresh() async -> Bool {
        guard let endpoint else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let batch = try JSONDecoder().decode(QuoteBatch.self, from: data)
            guard !batch.quotes.isEmpty else { return false }
            QuoteStore.shared.saveQuotes(batch)
            return true
        } catch {
            // Bewusst still fehlschlagen: Fallback ist immer die gebündelte Seed-Datei,
            // die App soll nie wegen eines Netzwerkfehlers kaputtgehen.
            return false
        }
    }
}
