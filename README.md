# Daily Mindset – Setup-Anleitung

Ein iOS-App-Grundgerüst: Homescreen-Widget mit täglichem Mindset-/Motivationsspruch,
Abo-Modell (Free: 1 Kategorie, Premium: alle Kategorien + mehr), Content kommt aus
einer KI-Pipeline statt einer festen Liste.

Du brauchst dafür: einen Mac mit Xcode 15+ und ein Apple-Developer-Konto (99 $/Jahr,
nur für den App-Store-Upload nötig – zum Testen im Simulator reicht ein kostenloses Konto).

## 1. Projekt generieren

Das Xcode-Projekt (`.xcodeproj`) ist absichtlich NICHT im Ordner enthalten – die ist eine
fehleranfällige, riesige XML-Datei, die man nicht von Hand pflegen sollte. Stattdessen
liegt hier eine `project.yml` (XcodeGen-Spec), aus der das Projekt automatisch generiert wird.

```bash
brew install xcodegen
cd DailyMindset
xcodegen generate
open DailyMindset.xcodeproj
```

Jedes Mal, wenn du `project.yml` änderst (z.B. neue Datei-Gruppen, neue Settings),
einfach `xcodegen generate` erneut ausführen – das Projekt wird sauber neu gebaut,
ohne dass alte Xcode-Projektleichen liegen bleiben.

## 2. Team & Bundle-ID eintragen

In Xcode, für **beide** Targets (`DailyMindset` und `MindsetWidgetExtension`):

1. Target auswählen → Tab **Signing & Capabilities**
2. Dein Team auswählen (Apple-Developer-Account)
3. Bundle-Identifier ggf. anpassen, falls `com.maxdeike.dailymindset` schon vergeben ist
   (dann auch in `project.yml` UND in `Shared/AppGroup.swift` konsistent ändern!)

## 3. App Group aktivieren

Beide Targets brauchen dieselbe App-Group-ID (`group.com.maxdeike.dailymindset`), damit
App und Widget Daten teilen können:

1. [developer.apple.com](https://developer.apple.com/account) → **Identifiers** → deine
   beiden App-IDs (App + Widget-Extension) → Capability **App Groups** aktivieren
2. Dort die Gruppe `group.com.maxdeike.dailymindset` anlegen bzw. auswählen
3. In Xcode sollte die Capability durch die `project.yml`-Entitlements bereits automatisch
   gesetzt sein – falls nicht: Signing & Capabilities → "+ Capability" → App Groups → Häkchen setzen

## 4. StoreKit lokal testen (ohne App Store Connect)

1. Ziehe `Config/Subscriptions.storekit` per Drag & Drop in dein Xcode-Projekt
   (Datei referenzieren, NICHT kopieren als Bundle-Resource)
2. **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** →
   `Subscriptions.storekit` auswählen
3. Jetzt kannst du im Simulator Käufe testen, ohne echtes Geld oder App Store Connect

Für den echten Store-Release musst du die zwei Abo-Produkte zusätzlich in
**App Store Connect** anlegen (gleiche Product-IDs wie in `SubscriptionManager.swift`:
`com.maxdeike.dailymindset.premium.monthly` / `.yearly`), inkl. Preis, Lokalisierung
und Screenshot für die Subscription-Review.

## 5. Widget testen

Nach dem Bauen: im Simulator/Gerät Homescreen gedrückt halten → „+“ → „Daily Mindset“
suchen → Größe wählen. Für die Lock-Screen-Variante: Sperrbildschirm gedrückt halten
→ Anpassen → Widget hinzufügen.

## 6. Content-Pipeline (KI-generierte Sprüche) einrichten

Die App startet mit einer gebündelten Seed-Liste (`Shared/quotes_seed.json`, ~18 Sprüche),
damit sie nie leer ist. Für echte tägliche KI-generierte Sprüche:

1. **Lokal testen:**
   ```bash
   cd ContentPipeline
   pip install -r requirements.txt
   export ANTHROPIC_API_KEY=sk-ant-...
   python generate_quotes.py --days 30 --out quotes.json
   ```
2. **Automatisiert & gehostet (empfohlen):** Die Datei `.github/workflows/generate-quotes.yml`
   lässt das Skript 1x/Woche via GitHub Actions laufen und committet `ContentPipeline/quotes.json`
   automatisch. Dafür:
   - Repo auf GitHub pushen
   - Unter **Settings → Secrets → Actions** ein Secret `ANTHROPIC_API_KEY` anlegen
   - Unter **Settings → Pages** GitHub Pages für den Branch `main`, Ordner `/ContentPipeline`
     aktivieren → du bekommst eine URL wie
     `https://<user>.github.io/<repo>/quotes.json`
3. Diese URL in `App/Services/RemoteQuoteService.swift` bei `endpoint` eintragen.
4. Fertig: Die App holt beim Start (und periodisch im Hintergrund via `BGAppRefreshTask`)
   die aktuelle Datei, schreibt sie in den App-Group-Container, das Widget liest sie beim
   nächsten Timeline-Reload.

Wichtig: Das Widget selbst ruft **nie** das Netzwerk auf (WidgetKit-Extensions sollten
das generell vermeiden) – nur die Haupt-App lädt nach und reicht es weiter.

## 7. App-Store-Submission – worauf achten

- **App-Review-Richtlinien 3.1.2**: Abo-Vorteile müssen im Paywall klar beschrieben sein
  (ist in `PaywallView.swift` bereits als Feature-Liste umgesetzt)
- Restore-Purchases-Button ist Pflicht (vorhanden, in Paywall & Settings)
- Für Kinder-/Health-Claims gibt's hier keine Berührungspunkte, aber generell: Motivations-
  sprüche dürfen keine medizinischen/psychologischen Heilsversprechen machen – reine
  Unterhaltungs-/Inspirations-App positionieren
- Screenshots für Review: mind. 1 Screenshot, der das Widget auf dem Homescreen zeigt
  (Apple will bei Widget-Apps sehen, dass es wirklich funktioniert)

## Projektstruktur

```
DailyMindset/
├── project.yml                    # XcodeGen-Spec (erzeugt das .xcodeproj)
├── App/                           # Haupt-App (SwiftUI)
│   ├── DailyMindsetApp.swift
│   ├── Views/                     # ContentView, PaywallView, SettingsView
│   └── Services/                  # SubscriptionManager, RemoteQuoteService,
│                                   # BackgroundRefreshManager, AppViewModel
├── MindsetWidget/                  # Widget-Extension (WidgetKit)
│   ├── MindsetWidgetBundle.swift
│   ├── MindsetWidgetProvider.swift
│   └── MindsetWidgetEntryView.swift
├── Shared/                        # Von App + Widget gemeinsam genutzt
│   ├── Quote.swift / QuoteCategory.swift
│   ├── QuoteStore.swift            # App-Group-Zugriff (Kernstück)
│   ├── AppGroup.swift
│   └── quotes_seed.json            # Fallback-Sprüche, offline & Tag 1
├── ContentPipeline/                # KI-Content-Generierung (Python, läuft außerhalb der App)
│   ├── generate_quotes.py
│   └── requirements.txt
├── .github/workflows/
│   └── generate-quotes.yml         # Automatisierte wöchentliche Content-Generierung
└── Config/
    └── Subscriptions.storekit      # Lokale StoreKit-Testkonfiguration
```

## Nächste sinnvolle Schritte (nicht mehr Teil dieses Grundgerüsts)

- App-Icon & echtes Branding (aktuell Platzhalter-Farben/SF-Symbols)
- Onboarding-Screen beim ersten Start (kurz erklären: Widget hinzufügen, Kategorien wählen)
- Mehr Widget-Styles als Premium-Feature (z.B. andere Farbschemata) – Struktur ist schon
  darauf vorbereitet, einfach weitere `WidgetConfiguration`-Varianten ergänzen
- Eigene Domain statt GitHub Pages fürs Hosting von `quotes.json`, falls gewünscht
