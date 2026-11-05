import Foundation

/// Shared HTTP helper: proper user agent, 20s timeout, 2xx check.
enum HTTP {
    static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

/// Loads the curated playtest feed (playtests.json on GitHub), caches
/// the last good payload in UserDefaults and serves the cache offline.
@MainActor
final class FeedStore: ObservableObject {
    @Published var items: [PlaytestItem] = []
    @Published var feedUpdated: Date?
    @Published var isLoading = false
    @Published var loadFailed = false

    static let feedURL = URL(string: "https://raw.githubusercontent.com/joe-design9/playtest-vault/main/playtests.json")!
    private static let cacheKey = "feed.cache.v1"

    private let uiTestMode: Bool
    private var didInitialLoad = false

    init(uiTestMode: Bool) {
        self.uiTestMode = uiTestMode
        if uiTestMode {
            items = SampleData.feedItems
            feedUpdated = Date()
        } else if let cached = Self.readCache() {
            items = cached.playtests
            feedUpdated = cached.updatedDate
        }
    }

    func loadIfNeeded() async {
        guard !didInitialLoad else { return }
        didInitialLoad = true
        await refresh()
    }

    func refresh() async {
        if uiTestMode { return }
        isLoading = true
        do {
            let data = try await HTTP.get(Self.feedURL)
            let feed = try JSONDecoder().decode(PlaytestFeed.self, from: data)
            items = feed.playtests
            feedUpdated = feed.updatedDate
            loadFailed = false
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        } catch {
            // Offline or bad payload: keep showing whatever we have.
            loadFailed = items.isEmpty
        }
        isLoading = false
    }

    private static func readCache() -> PlaytestFeed? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(PlaytestFeed.self, from: data)
    }
}

/// Bundled sample content used only in -UITestMode (QA screenshots):
/// the Discover feed and the Demos list render without any network.
enum SampleData {
    static var feedItems: [PlaytestItem] {
        let now = Date()
        return [
            PlaytestItem(
                id: "sample-mecha-arena",
                title: "Mecha Arena — Playtest",
                platform: "Steam",
                status: "Live now",
                deadline: now.addingTimeInterval(3 * 86400),
                url: "https://store.steampowered.com",
                image: nil,
                descEN: "Closed multiplayer playtest for the arena mech battler. Servers are live all weekend, feedback survey at the end.",
                descDE: "Geschlossener Multiplayer-Playtest für den Arena-Mech-Battler. Server laufen das ganze Wochenende, Feedback-Umfrage am Ende.",
                tags: ["Multiplayer", "Action", "Mechs"]
            ),
            PlaytestItem(
                id: "sample-deep-sea",
                title: "Deep Sea Tactics — Beta",
                platform: "Xbox",
                status: "Signups open",
                deadline: now.addingTimeInterval(30 * 3600),
                url: "https://www.xbox.com",
                image: nil,
                descEN: "Sign up for the console beta of the turn-based deep sea strategy game. Invites go out in waves.",
                descDE: "Melde dich für die Konsolen-Beta des rundenbasierten Tiefsee-Strategiespiels an. Einladungen kommen in Wellen.",
                tags: ["Strategy", "Beta", "Console"]
            ),
            PlaytestItem(
                id: "sample-kart-legends",
                title: "Kart Legends — Demo Weekend",
                platform: "PlayStation",
                status: "Coming soon",
                deadline: now.addingTimeInterval(10 * 86400),
                url: "https://www.playstation.com",
                image: nil,
                descEN: "A demo weekend is planned ahead of launch. Wishlist the game to get notified when the demo drops.",
                descDE: "Ein Demo-Wochenende ist vor dem Launch geplant. Setz das Spiel auf die Wunschliste, um beim Demo-Start benachrichtigt zu werden.",
                tags: ["Racing", "Demo", "Arcade"]
            ),
        ]
    }

    static var demos: [SteamDemo] {
        [
            SteamDemo(demoAppID: -1, fullGameID: -1, title: "Mecha Arena Demo"),
            SteamDemo(demoAppID: -2, fullGameID: -2, title: "Deep Sea Tactics Demo"),
            SteamDemo(demoAppID: -3, fullGameID: -3, title: "Kart Legends Demo"),
        ]
    }

    static var sampleDetails: SteamGameDetails {
        SteamGameDetails(
            name: "Sample Game",
            headerImage: nil,
            shortDescription: Lang.tr(
                "Dies ist ein Platzhalter-Detail im QA-Modus. Im echten Betrieb lädt die App hier die Kurzbeschreibung direkt von Steam.",
                "This is a placeholder detail in QA mode. In normal use the app loads the short description directly from Steam here."
            ),
            genres: ["Action", "Indie"],
            releaseDate: "2026"
        )
    }
}
