import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    /// Damit Spruch/Streak nicht veraltet stehen bleiben, wenn die App über Nacht nur
    /// in den Hintergrund (nicht komplett beendet) und morgens wieder in den Vordergrund
    /// geholt wird – .task/.onAppear laufen sonst nur einmal pro kaltem App-Start.
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPaywall = false
    /// Eigene Sprüche lassen sich direkt aus der Kategorien-Liste heraus hinzufügen
    /// (kleines "+" bei "Eigene"), ohne erst ins "Sprüche"-Sheet wechseln zu müssen.
    @State private var showAddCustomQuote = false
    /// Welche Kategorie gerade ihre Bildergalerie zeigt (siehe categoryPicker /
    /// CategoryBackgroundGalleryView). nil = keine Galerie offen.
    @State private var categoryForGallery: QuoteCategory?
    /// Welcher Spruch gerade in der Karte angezeigt wird, wenn der Nutzer durch
    /// bereits erschienene Sprüche swiped. nil = automatisch der neueste (heutige).
    @State private var displayedQuoteID: String?
    /// Als Bild gerenderter Spruch, bereit fürs System-Teilen-Menü (kostenloses
    /// Feature, siehe quoteCard-Overlay – bewusst kein Premium-Gate, da jedes
    /// geteilte Bild quasi kostenlose Werbung für die App ist).
    @State private var shareItem: ShareableImage?
    @State private var reflectionText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    streakBadge
                    quoteCard
                    reflectionPrompt
                    activateButton
                    nextQuoteCountdown
                    pinnedQuoteBanner
                    categoryPicker
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.primary, lineWidth: 1.5)
                        )
                        .shadow(color: Color.primary.opacity(0.45), radius: 14)
                    widgetInstructions
                }
                .padding()
            }
            .background(alignment: .center) { appBackground }
            .navigationTitle("Daily Mindset")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .sheet(isPresented: $showAddCustomQuote) {
                AddCustomQuoteView { text, author in
                    viewModel.addCustomQuote(text: text, author: author, isPremium: subscriptionManager.isPremium)
                }
            }
            .sheet(item: $categoryForGallery) { category in
                CategoryBackgroundGalleryView(category: category, viewModel: viewModel, isPremium: subscriptionManager.isPremium)
            }
            .task(id: subscriptionManager.isPremium) {
                viewModel.refreshTodaysQuote(isPremium: subscriptionManager.isPremium)
                reflectionText = viewModel.reflection(forQuoteID: displayedQuote?.id ?? "")?.text ?? ""
            }
            .onChange(of: displayedQuoteID) { _, _ in
                reflectionText = viewModel.reflection(forQuoteID: displayedQuote?.id ?? "")?.text ?? ""
            }
            .onAppear {
                // Kostenloses Feature für alle Nutzer (siehe AppViewModel.recordDailyOpen) –
                // zählt pro Kalendertag einmal, mehrfaches onAppear am selben Tag ist unschädlich.
                viewModel.recordDailyOpen()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard newPhase == .active, oldPhase != .active else { return }
                // App kommt aus dem Hintergrund zurück (z.B. nach Mitternacht) -> Spruch
                // und Streak neu bestimmen, statt den Stand vom letzten kalten Start zu zeigen.
                viewModel.refreshTodaysQuote(isPremium: subscriptionManager.isPremium)
                viewModel.recordDailyOpen()
            }
        }
        .preferredColorScheme(.dark)
    }

    /// App-Hintergrund im neuen "Noir Editorial"-Look (Max' Wahl): flaches, fast
    /// reines Schwarz ohne Farbverlauf oder Glanzeffekte – bewusst nüchtern und
    /// konsequent in Schwarz-Weiß-Grau gehalten, kein Lila/Gold mehr wie zuvor.
    private var appBackground: some View {
        Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
            .ignoresSafeArea()
    }

    /// Kleines Streak-Badge über der Spruch-Karte: "X Tage in Folge" mit Flammen-Icon.
    /// Bewusst kein Premium-Feature – soll alle Nutzer motivieren, täglich zurückzukommen.
    /// Erscheint erst, sobald recordDailyOpen() (siehe .onAppear) den Streak gesetzt hat,
    /// damit beim allerersten Rendern nicht kurz "0 Tage" aufblitzt.
    @ViewBuilder
    private var streakBadge: some View {
        if viewModel.currentStreak > 0 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.accentColor)
                Text(viewModel.currentStreak == 1 ? "1 Tag in Folge" : "\(viewModel.currentStreak) Tage in Folge")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.primary.opacity(0.4), radius: 10)
        }
    }

    /// Alle Sprüche, durch die man auf der Hauptkarte durchswipen kann – dieselbe
    /// Datenbasis wie der "Alle Sprüche"-Tab, Index 0 ist immer der aktuelle/heutige.
    private var browsableQuotes: [Quote] {
        viewModel.appearedQuotes(isPremium: subscriptionManager.isPremium)
    }

    /// ID-basiert statt Index-basiert: fällt automatisch sauber auf den heutigen
    /// Spruch zurück, falls sich die Liste ändert (z.B. Kategorie-Wechsel) und die
    /// zuvor angezeigte ID nicht mehr enthalten ist.
    private var displayedIndex: Int {
        guard let id = displayedQuoteID else { return 0 }
        return browsableQuotes.firstIndex { $0.id == id } ?? 0
    }

    private var displayedQuote: Quote? {
        if browsableQuotes.indices.contains(displayedIndex) {
            return browsableQuotes[displayedIndex]
        }
        return viewModel.todaysQuote
    }

    private var isShowingToday: Bool {
        guard let displayed = displayedQuote, let today = viewModel.todaysQuote else { return true }
        return displayed.id == today.id
    }

    /// Richtung "zurück zu neueren/heutigem Spruch" (Index sinkt).
    private func showNewerQuote() {
        let idx = displayedIndex
        guard idx > 0 else { return }
        displayedQuoteID = browsableQuotes[idx - 1].id
    }

    /// Richtung "weiter zu älteren Sprüchen" (Index steigt).
    private func showOlderQuote() {
        let idx = displayedIndex
        guard idx + 1 < browsableQuotes.count else { return }
        displayedQuoteID = browsableQuotes[idx + 1].id
    }

    /// Rendert den übergebenen Spruch im gewählten Widget-Design als quadratisches
    /// 1080x1080-Bild (passend für Instagram Story/Post, WhatsApp etc.) und schreibt
    /// es als PNG in einen temporären Ordner. Läuft synchron auf dem Main-Thread –
    /// ImageRenderer ist für eine so einfache Karte in der Praxis sofort fertig.
    @MainActor
    fileprivate static func renderShareImage(quote: Quote, style: WidgetStyle) -> URL? {
        let card = ShareQuoteCardView(quote: quote, style: style)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("daily-mindset-\(quote.id)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func relativeDateLabel(for quote: Quote) -> String {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        keyFormatter.timeZone = .current
        guard let date = keyFormatter.date(from: quote.dateKey) else { return "" }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Heute" }
        if calendar.isDateInYesterday(date) { return "Gestern" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d. MMMM"
        displayFormatter.locale = Locale(identifier: "de_DE")
        return displayFormatter.string(from: date)
    }

    private var quoteCard: some View {
        let quote = displayedQuote
        let canShowNewer = displayedIndex > 0
        let canShowOlder = displayedIndex + 1 < browsableQuotes.count

        return VStack(spacing: 14) {
            if let quote {
                HStack {
                    Text(quote.category.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.2)
                        .foregroundStyle(Color.accentColor)

                    if !isShowingToday {
                        Spacer()
                        Text(Self.relativeDateLabel(for: quote))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                // Reserviert Platz rechts, damit das Datums-Label nicht unter die
                // Icons (Teilen + Stern, oben rechts über der Karte) rutscht.
                .padding(.trailing, 82)

                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 40, height: 3)

                Text(quote.text)
                    .font(viewModel.quoteFont.font(textStyle: .title2, size: 22, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .id(quote.id)
                    .transition(.opacity)

                if let author = quote.author {
                    Text("– \(author)")
                        .font(viewModel.quoteFont.font(textStyle: .subheadline, size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 40, height: 3)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Keine Kategorie ausgewählt")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Wähle unten mindestens eine Kategorie aus, damit dir ein Spruch angezeigt werden kann.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary, lineWidth: 1.5)
        )
        .shadow(color: Color.primary.opacity(0.45), radius: 16)
        // Stern (Favorit) oben rechts. Die Widget-Aktivierung passiert jetzt über
        // den deutlich sichtbaren "Aktiv"-Button unter der Karte statt über ein
        // kleines Pin-Icon hier.
        .overlay(alignment: .topTrailing) {
            if let quote {
                HStack(spacing: 8) {
                    Button {
                        if let url = Self.renderShareImage(quote: quote, style: viewModel.selectedWidgetStyle) {
                            shareItem = ShareableImage(url: url)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                            .background(Circle().fill(.thinMaterial))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.toggleFavorite(quote)
                    } label: {
                        Image(systemName: viewModel.isFavorite(quote) ? "star.fill" : "star")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(viewModel.isFavorite(quote) ? Color.accentColor : .secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                            .background(Circle().fill(.thinMaterial))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
        }
        // Pfeilsymbole links/rechts als sichtbarer Hinweis, dass man zu anderen
        // Sprüchen swipen kann – zusätzlich zur Swipe-Geste selbst.
        .overlay(alignment: .leading) {
            if canShowNewer {
                swipeChevron(systemName: "chevron.left", action: showNewerQuote)
                    .padding(.leading, 6)
            }
        }
        .overlay(alignment: .trailing) {
            if canShowOlder {
                swipeChevron(systemName: "chevron.right", action: showOlderQuote)
                    .padding(.trailing, 6)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -40 {
                        showOlderQuote()
                    } else if value.translation.width > 40 {
                        showNewerQuote()
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: displayedQuoteID)
    }

    /// Kleine Mini-Reflexion direkt unter dem Tagesspruch (kostenloses Feature,
    /// siehe AppViewModel.saveReflection / ReflectionHistoryView): ein Satz dazu,
    /// was der Spruch gerade bedeutet – sammelt sich im Reflexions-Archiv
    /// (Buch-Symbol oben rechts). isSaved ist rein abgeleitet (kein eigener
    /// Speicher-Status nötig): sobald der aktuelle Feldinhalt exakt der bereits
    /// gespeicherten Notiz zu diesem Spruch entspricht, zeigt der Button einen
    /// Haken statt des Pfeils.
    @ViewBuilder
    private var reflectionPrompt: some View {
        if let quote = displayedQuote {
            let trimmed = reflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSaved = !trimmed.isEmpty && viewModel.reflection(forQuoteID: quote.id)?.text == reflectionText

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Was bedeutet das heute für dich?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    TextField("Ein Satz reicht …", text: $reflectionText)
                        .font(.subheadline)
                        .onSubmit { saveReflection(for: quote) }

                    Button {
                        saveReflection(for: quote)
                    } label: {
                        Image(systemName: isSaved ? "checkmark" : "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.4 : 1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.primary.opacity(0.45), radius: 14)
        }
    }

    private func saveReflection(for quote: Quote) {
        viewModel.saveReflection(text: reflectionText, for: quote)
    }

    /// Deutlicher, beschrifteter Button statt eines kleinen Pin-Icons: zeigt klar
    /// an, ob der gerade angezeigte (ggf. durchgeswipte) Spruch der ist, der aktuell
    /// im Widget läuft – und macht die Aktivierung bewusst zu einem eigenen Tap,
    /// statt das Widget beim bloßen Durchblättern automatisch zu ändern.
    @ViewBuilder
    private var activateButton: some View {
        if let quote = displayedQuote {
            let isPremium = subscriptionManager.isPremium
            let isActive = viewModel.pinnedQuoteID == quote.id

            Button {
                if !isPremium {
                    showPaywall = true
                } else if isActive {
                    viewModel.unpinQuote()
                } else {
                    viewModel.pinQuote(quote, isPremium: true)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : (isPremium ? "pin.fill" : "lock.fill"))
                    Text(isActive ? "Aktiv – läuft im Widget" : "Als Widget-Spruch aktivieren")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(isActive ? Color.accentColor : (isPremium ? Color.primary : .secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isActive ? Color.accentColor.opacity(0.5) : (isPremium ? Color.primary : Color.primary.opacity(0.25)),
                            lineWidth: 1.4
                        )
                )
                .shadow(
                    color: (isActive ? Color.accentColor : Color.primary).opacity(isPremium ? 0.4 : 0),
                    radius: 12
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }

    private func swipeChevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .background(Circle().fill(.thinMaterial))
        }
        .buttonStyle(.plain)
    }

    /// Zählt runter bis Mitternacht (lokale Zeit), wenn der nächste Spruch rotiert.
    /// TimelineView(.periodic) statt eines eigenen Timer-Objekts: SwiftUI kümmert
    /// sich selbst ums Starten/Stoppen, auch wenn die View verschwindet/wiederkommt.
    private var nextQuoteCountdown: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                Text("Neuer Spruch in \(Self.timeUntilNextQuote(from: context.date))")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    private static func timeUntilNextQuote(from date: Date) -> String {
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) else {
            return "–"
        }
        let comps = calendar.dateComponents([.hour, .minute], from: date, to: nextMidnight)
        let hours = comps.hour ?? 0
        let minutes = max(comps.minute ?? 0, 0)
        if hours > 0 {
            return "\(hours) Std. \(minutes) Min."
        }
        return "\(minutes) Min."
    }

    /// Hinweis auf der Hauptseite, falls gerade ein Spruch fürs Widget angeheftet ist –
    /// sonst könnte es verwirren, dass das Widget nicht mit dem Tagesspruch oben
    /// übereinstimmt, der in der App angezeigt wird.
    @ViewBuilder
    private var pinnedQuoteBanner: some View {
        if let pinned = viewModel.pinnedQuote, pinned.id != displayedQuote?.id {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                Text("Widget zeigt angehefteten Spruch: „\(pinned.text)“")
                    .font(.caption2)
                    .lineLimit(1)
                Spacer()
                Button("Lösen") { viewModel.unpinQuote() }
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.primary.opacity(0.4), radius: 10)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategorien")
                .font(.headline)

            // "Eigene" (.custom) ist als Kategorie wählbar (Premium), damit die eigenen
            // Sprüche mit ins Widget-Rotation einbezogen werden können, siehe QuoteCategory.custom.
            // Bei "Eigene" gibt es zusätzlich ein eigenes "+" oben rechts auf der Kachel, damit
            // man einen neuen Spruch hier auf der Hauptseite anlegen kann, ohne erst ins
            // "Sprüche"-Sheet wechseln zu müssen (Hinzufügen bleibt dabei kostenlos,
            // unabhängig davon, ob die Kategorie selbst gerade gesperrt ist).
            // Radio-Verhalten: es ist immer genau eine Kategorie ausgewählt (siehe
            // AppViewModel.selectCategory) – der Tages-/Widget-Spruch kommt ohnehin nur
            // aus einer Kategorie, mehrere gleichzeitig anzuhaken hätte nur suggeriert,
            // dass alle einfließen.
            //
            // Einzelne Kacheln statt einem durchgehenden Listenblock (Max' Wunsch): die
            // ausgewählte Kategorie bekommt einen weißen "LED"-Rand mit Glow, unausgewählte
            // nur einen dezenten dünnen Rand.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                ForEach(QuoteCategory.allCases) { category in
                    categoryTile(category)
                }
            }
        }
    }

    private func categoryTile(_ category: QuoteCategory) -> some View {
        let isFree = QuoteCategory.freeCategories.contains(category)
        let isSelected = viewModel.selectedCategories.contains(category)
        let isLocked = !subscriptionManager.isPremium && !isFree

        return ZStack(alignment: .topTrailing) {
            Button {
                if isLocked {
                    showPaywall = true
                } else {
                    viewModel.selectCategory(category, isPremium: subscriptionManager.isPremium)
                    // Bildergalerie nur für Premium (eigener Hintergrund ist wie
                    // bisher Premium-gated) – sonst bliebe sie leer wirkungslos.
                    if subscriptionManager.isPremium {
                        categoryForGallery = category
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: isLocked ? "lock.fill" : category.symbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(isSelected ? 0.05 : 0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.16), lineWidth: isSelected ? 1.5 : 1)
                )
                .shadow(color: isSelected ? Color.primary.opacity(0.45) : .clear, radius: 14)
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Als eigenständiger Button neben (nicht innerhalb) dem Auswahl-Button,
            // damit sich beide Taps zuverlässig nicht gegenseitig ins Gehege kommen.
            HStack(spacing: 4) {
                if category == .custom {
                    Button {
                        showAddCustomQuote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.primary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(10)
        }
    }


    private var widgetInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Widget hinzufügen", systemImage: "square.grid.2x2")
                .font(.headline)
            Text("Homescreen gedrückt halten → „+“ oben links → „Daily Mindset“ suchen → Größe wählen → Hinzufügen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary, lineWidth: 1.5)
        )
        .shadow(color: Color.primary.opacity(0.45), radius: 14)
    }
}

/// Eigene Design-Seite (Max' Wunsch, siehe "4 Tabs"-Entscheidung): bündelt
/// Widget-Design, Textfarbe, Schriftart und Leuchtender Rand abseits der
/// Hauptseite, über die Tab-Leiste erreichbar. Bewusst im selben File wie
/// ContentView (wie FavoritesView unten) – alles reguläre, unabhängige Views.
struct DesignView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                widgetStylePicker
                    .padding()
            }
            .background(alignment: .center) {
                Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
                    .ignoresSafeArea()
            }
            .navigationTitle("Design")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.saveCustomBackground(data: data, isPremium: subscriptionManager.isPremium)
                    }
                    photoPickerItem = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Jede Design-Option (Widget-Design, Textfarbe, Schriftart, Leuchtender Rand)
    /// steht als eigene, in sich geschlossene Karte mit weißem LED-Glow-Rand da,
    /// statt in einem einzigen grossen Block zu stecken (Max' Wunsch) – Optik wie
    /// die "Glow Accent Cards" aus dem zuvor gezeigten Design-Entwurf.
    private var widgetStylePicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Widget-Design")
                            .font(.headline)
                        if !subscriptionManager.isPremium {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(WidgetStyle.allCases) { style in
                                widgetStyleSwatch(style)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    if subscriptionManager.isPremium && !viewModel.hasCustomBackground {
                        Text("Tipp: Bei „Foto“ kannst du ein eigenes Bild als Hintergrund wählen – es bleibt nur auf deinem Gerät.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }

            // Eigene Textfarbe ist global (wie die Schriftart) – wirkt auf jedes
            // Widget-Design, nicht nur auf "Foto".
            if subscriptionManager.isPremium {
                settingsCard {
                    customTextColorPicker
                }
            }

            // Schriftart ist global (anders als die Textfarbe nicht an "Foto"
            // gekoppelt) – daher immer sichtbar, unabhängig vom gewählten Design.
            settingsCard {
                quoteFontPicker
            }

            // Leuchtender Rand ist wie Textfarbe/Schriftart global – unabhängig vom
            // gewählten Widget-Design frei an-/ausschaltbar und einfärbbar.
            if subscriptionManager.isPremium {
                settingsCard {
                    glowBorderPicker
                }
            }
        }
    }

    /// Gemeinsame "Glow Accent Card"-Hülle für die einzelnen Design-Optionen: dezent
    /// getönter Hintergrund plus weißer LED-Rand mit Glow, im selben Vokabular wie
    /// die einzelnen Kategorien-Kacheln (categoryTile) gehalten.
    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.primary.opacity(0.45), radius: 14)
    }

    /// Leuchtender Rand ums Widget (Premium, siehe QuoteStore.glowBorderEnabled/
    /// glowBorderColor): unabhängig vom gewählten Widget-Design frei an-/ausschaltbar
    /// und in der Farbe wählbar.
    private var glowBorderPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { viewModel.glowBorderEnabled },
                set: { viewModel.setGlowBorderEnabled($0, isPremium: subscriptionManager.isPremium) }
            )) {
                Text("Leuchtender Rand")
                    .font(.subheadline)
            }
            .tint(Color.accentColor)

            if viewModel.glowBorderEnabled {
                ColorPicker(selection: Binding(
                    get: { viewModel.glowBorderColor },
                    set: { viewModel.setGlowBorderColor($0, isPremium: subscriptionManager.isPremium) }
                ), supportsOpacity: false) {
                    Text("Randfarbe")
                        .font(.subheadline)
                }
            }
        }
    }

    /// Frei wählbare Schriftart für den Spruchtext (Premium, siehe QuoteFont) – wirkt
    /// auf Hauptkarte, Teilen-Bild und Widget, unabhängig vom Widget-Design.
    private var quoteFontPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Schriftart")
                    .font(.headline)
                if !subscriptionManager.isPremium {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(QuoteFont.allCases) { font in
                        quoteFontSwatch(font)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func quoteFontSwatch(_ font: QuoteFont) -> some View {
        let isSelected = subscriptionManager.isPremium && viewModel.quoteFont == font
        let isLocked = !subscriptionManager.isPremium

        return Button {
            if isLocked {
                showPaywall = true
            } else {
                viewModel.setQuoteFont(font, isPremium: subscriptionManager.isPremium)
            }
        } label: {
            VStack(spacing: 6) {
                Text("Aa")
                    .font(font.font(size: 26, weight: .semibold))
                    .frame(width: 56, height: 44)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )

                HStack(spacing: 3) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                    }
                    Text(font.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Freie Farbwahl für den Spruchtext – per Farbenrad (im ColorPicker-Sheet unter
    /// dem Tab "Spektrum"/Rad-Symbol). Ohne eigene Wahl bleibt es beim festen
    /// Farbschema des jeweiligen Widget-Designs; daher zeigt das Rad beim Öffnen die
    /// aktuell wirksame Farbe, und "Zurücksetzen" ist nur sichtbar, wenn der Nutzer
    /// überhaupt schon eine eigene Farbe gewählt hat.
    private var customTextColorPicker: some View {
        HStack {
            ColorPicker(selection: Binding(
                get: { viewModel.customTextColor ?? viewModel.selectedWidgetStyle.primaryTextColor },
                set: { viewModel.setCustomTextColor($0, isPremium: subscriptionManager.isPremium) }
            ), supportsOpacity: false) {
                Text("Textfarbe")
                    .font(.subheadline)
            }

            if viewModel.customTextColor != nil {
                Button {
                    viewModel.resetCustomTextColor(isPremium: subscriptionManager.isPremium)
                } label: {
                    Text("Zurücksetzen")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func widgetStyleSwatch(_ style: WidgetStyle) -> some View {
        let isSelected = subscriptionManager.isPremium && viewModel.selectedWidgetStyle == style
        let isLocked = !subscriptionManager.isPremium

        // Bei "Foto": ein Tap auf die Kachel soll IMMER etwas sichtbar tun – entweder
        // erstmalig ein Bild wählen, auf den gespeicherten Stil wechseln, oder (wenn
        // "Foto" schon aktiv ist) direkt den Bildauswahl-Dialog öffnen, um das Foto zu
        // wechseln. Vorher passierte beim erneuten Antippen der bereits ausgewählten
        // Kachel nichts Sichtbares, und nur der winzige "Ändern"-Text darunter hat
        // funktioniert – das wurde leicht übersehen.
        return VStack(spacing: 6) {
            Button {
                if isLocked {
                    showPaywall = true
                } else if style == .photo && (!viewModel.hasCustomBackground || isSelected) {
                    showPhotoPicker = true
                } else {
                    viewModel.setWidgetStyle(style, isPremium: subscriptionManager.isPremium)
                }
            } label: {
                swatchTile(for: style, isSelected: isSelected, isLocked: isLocked)
            }
            .buttonStyle(.plain)

            if style == .photo && isSelected {
                Button {
                    showPhotoPicker = true
                } label: {
                    Text("Foto ändern")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Text(style.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
    }

    @ViewBuilder
    private func swatchTile(for style: WidgetStyle, isSelected: Bool, isLocked: Bool) -> some View {
        ZStack {
            switch style {
            case .photo:
                if let thumbnail = viewModel.customBackgroundThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            default:
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: style.backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: 52, height: 52)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(.black.opacity(0.55)))
                    .offset(x: 5, y: -5)
            } else if style == .photo && isSelected {
                // Zeigt direkt auf der Kachel, dass ein Tap hier das Foto wechselt.
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, Color.accentColor)
                    .background(Circle().fill(.white))
                    .offset(x: 6, y: -6)
            }
        }
    }
}

#Preview {
    DesignView(viewModel: AppViewModel())
        .environmentObject(SubscriptionManager.shared)
}

/// Liste der gespeicherten Lieblingssprüche UND aller bereits erschienenen Sprüche,
/// mit der Möglichkeit, einen davon fürs Widget anzuheften. Bewusst im selben File
/// wie ContentView untergebracht (statt als eigenes File im Xcode-Projekt), um
/// unnötige Projektdatei-Änderungen zu vermeiden – alles reguläre, unabhängige
/// SwiftUI-Views.
struct FavoritesView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: QuoteListTab = .favorites
    @State private var showPaywall = false
    @State private var showAddCustomQuote = false
    @State private var shareItem: ShareableImage?

    private enum QuoteListTab: String, CaseIterable, Identifiable {
        case favorites = "Favoriten"
        case all = "Alle Sprüche"
        case own = "Eigene"
        var id: String { rawValue }
    }

    private var favorites: [Quote] { viewModel.favoriteQuotes }
    private var allAppeared: [Quote] { viewModel.appearedQuotes(isPremium: subscriptionManager.isPremium) }
    private var ownQuotes: [Quote] { viewModel.customQuotes }
    private var currentList: [Quote] {
        switch selectedTab {
        case .favorites: return favorites
        case .all: return allAppeared
        case .own: return ownQuotes
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $selectedTab) {
                    ForEach(QuoteListTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                if currentList.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySymbolName,
                        description: Text(emptyDescription)
                    )
                } else {
                    List {
                        ForEach(currentList) { quote in
                            quoteRow(quote)
                        }
                        .onDelete { offsets in
                            switch selectedTab {
                            case .favorites:
                                for index in offsets {
                                    viewModel.toggleFavorite(favorites[index])
                                }
                            case .own:
                                for index in offsets {
                                    viewModel.deleteCustomQuote(ownQuotes[index], isPremium: subscriptionManager.isPremium)
                                }
                            case .all:
                                break
                            }
                        }
                        // Bei "Alle Sprüche" gibt es keine sinnvolle Löschen-Aktion (siehe
                        // .onDelete oben, case .all: break) – die Wisch-Geste würde sonst
                        // einen roten Löschen-Button zeigen, der nichts tut.
                        .deleteDisabled(selectedTab == .all)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Sprüche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                if selectedTab == .own {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            showAddCustomQuote = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAddCustomQuote) {
                AddCustomQuoteView { text, author in
                    viewModel.addCustomQuote(text: text, author: author, isPremium: subscriptionManager.isPremium)
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.url])
            }
        }
    }

    private var emptyTitle: String {
        switch selectedTab {
        case .favorites: return "Noch keine Favoriten"
        case .all: return "Noch keine Sprüche"
        case .own: return "Noch keine eigenen Sprüche"
        }
    }

    private var emptySymbolName: String {
        switch selectedTab {
        case .favorites: return "star"
        case .all: return "text.quote"
        case .own: return "pencil.and.scribble"
        }
    }

    private var emptyDescription: String {
        switch selectedTab {
        case .favorites: return "Tippe auf den Stern bei einem Spruch, um ihn hier zu sammeln."
        case .all: return "Hier sammeln sich nach und nach alle Sprüche, die du schon hattest."
        case .own: return "Füge eigene Sprüche hinzu, die dich motivieren – mit dem \"+\" oben rechts."
        }
    }

    private func quoteRow(_ quote: Quote) -> some View {
        let isPinned = viewModel.pinnedQuoteID == quote.id
        let isPremium = subscriptionManager.isPremium

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(quote.category.displayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Text(quote.text)
                    .font(.body)
                if let author = quote.author {
                    Text("– \(author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            // Explizite .frame()s auf jedem Button: ohne sie bekommt ein kleines
            // Icon-Only-Button automatisch eine größere, unsichtbare Tap-Fläche
            // (Mindest-Tapgröße), die bei zwei eng gestapelten Buttons (Stern +
            // Pin) überlappt – man trifft dann beim unteren Button versehentlich
            // immer den oberen. Mit fixer Frame-Größe + .contentShape sind die
            // Tap-Flächen sauber getrennt.
            VStack(spacing: 20) {
                Button {
                    if let url = ContentView.renderShareImage(quote: quote, style: viewModel.selectedWidgetStyle) {
                        shareItem = ShareableImage(url: url)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                Button {
                    viewModel.toggleFavorite(quote)
                } label: {
                    Image(systemName: viewModel.isFavorite(quote) ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isFavorite(quote) ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                Button {
                    if !isPremium {
                        showPaywall = true
                    } else if isPinned {
                        viewModel.unpinQuote()
                    } else {
                        viewModel.pinQuote(quote, isPremium: true)
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .overlay(alignment: .topTrailing) {
                            if !isPremium {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(2.5)
                                    .background(Circle().fill(.black.opacity(0.55)))
                                    .offset(x: 2, y: -2)
                            }
                        }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }
}

/// Privates Archiv aller bisherigen Mini-Reflexionen (siehe
/// ContentView.reflectionPrompt), neueste zuerst. Eigener Tab in der
/// Tab-Leiste (RootTabView), kein Sheet mehr.
struct ReflectionHistoryView: View {
    @ObservedObject var viewModel: AppViewModel

    private var sortedReflections: [Reflection] {
        viewModel.reflections.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedReflections.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Reflexionen",
                        systemImage: "text.book.closed",
                        description: Text("Schreib unter dem Tagesspruch einen Satz dazu – er sammelt sich hier.")
                    )
                } else {
                    List {
                        ForEach(sortedReflections) { reflection in
                            reflectionRow(reflection)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteReflection(sortedReflections[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reflexionen")
        }
        .preferredColorScheme(.dark)
    }

    private func reflectionRow(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateLabel(forDateKey: reflection.dateKey).uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
            Text("„\(reflection.quoteText)“")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
            Text(reflection.text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }

    private static func dateLabel(forDateKey dateKey: String) -> String {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        keyFormatter.timeZone = .current
        guard let date = keyFormatter.date(from: dateKey) else { return "" }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Heute" }
        if calendar.isDateInYesterday(date) { return "Gestern" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEEE, d. MMMM"
        displayFormatter.locale = Locale(identifier: "de_DE")
        return displayFormatter.string(from: date)
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
        .environmentObject(SubscriptionManager.shared)
}

/// Identifiable-Wrapper, damit .sheet(item:) die gerenderte Bild-Datei
/// zum Teilen präsentieren kann.
struct ShareableImage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Dünner Wrapper um UIActivityViewController – zuverlässiger für Bild-Dateien
/// (inkl. "In Fotos sichern", Instagram-Story etc.) als SwiftUIs ShareLink.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Quadratische "Teilen"-Karte für einen Spruch (1080x1080, passend für Instagram
/// Story/Post, WhatsApp-Status etc.) – nutzt dieselbe Farbsprache wie die Widgets
/// (siehe WidgetStyle), damit das geteilte Bild zum gewählten Look passt. Wird nicht
/// direkt angezeigt, sondern nur per ImageRenderer in ein PNG gerendert
/// (siehe ContentView.renderShareImage).
struct ShareQuoteCardView: View {
    let quote: Quote
    let style: WidgetStyle

    private let size: CGFloat = 1080

    /// Vom Nutzer frei gewählte Textfarbe (siehe QuoteStore.customTextColor und
    /// AppViewModel.setCustomTextColor) – gilt für jedes Widget-Design; ist noch
    /// keine eigene Farbe gewählt (nil), bleiben primaryTextColor(customTextColor:)/
    /// secondaryTextColor(customTextColor:) beim festen Farbschema des Stils.
    private var customTextColor: Color? { QuoteStore.shared.customTextColor }

    /// Vom Nutzer gewählte Schriftart (siehe QuoteStore.quoteFont/AppViewModel.setQuoteFont) –
    /// global, unabhängig vom gewählten Widget-Design.
    private var quoteFont: QuoteFont { QuoteStore.shared.quoteFont }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {
                Text(quote.category.displayName.uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(style.accentTextColor)

                Text(quote.text)
                    .font(quoteFont.font(size: 54, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(style.primaryTextColor(customTextColor: customTextColor))
                    .minimumScaleFactor(0.5)
                    .lineLimit(8)
                    .padding(.horizontal, 32)

                if let author = quote.author {
                    Text("– \(author)")
                        .font(.system(size: 26))
                        .foregroundStyle(style.secondaryTextColor(customTextColor: customTextColor))
                }
            }
            .padding(72)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Daily Mindset")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(1)
                }
                .foregroundStyle(style.secondaryTextColor(customTextColor: customTextColor))
                .padding(.bottom, 48)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .photo:
            if let uiImage = QuoteStore.shared.loadWidgetBackgroundImage() {
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                    LinearGradient(
                        colors: [.black.opacity(0.15), .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                // Fallback, falls "Foto" gewählt ist, aber (noch) kein Bild gespeichert wurde
                // (gleiches Verhalten wie im Widget selbst, siehe MindsetWidgetEntryView).
                LinearGradient(colors: WidgetStyle.classic.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        default:
            LinearGradient(colors: style.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Formular zum Anlegen eines eigenen Spruchs (kostenloses Feature, siehe
/// FavoritesView-Tab "Eigene"). onSave liefert den getrimmten Text und einen
/// optionalen Autor zurück; das eigentliche Speichern passiert im ViewModel.
struct AddCustomQuoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var author: String = ""
    let onSave: (String, String?) -> Void

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Spruch") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }
                Section("Autor (optional)") {
                    TextField("z.B. dein Name oder Quelle", text: $author)
                }
            }
            .navigationTitle("Eigener Spruch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(text, author.isEmpty ? nil : author)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
