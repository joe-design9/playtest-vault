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
                id: "god-save-birmingham",
                title: "God Save Birmingham \u{2014} Beta 2",
                platform: "Steam",
                status: "Live now",
                deadline: now.addingTimeInterval(4 * 86400),
                url: "https://store.steampowered.com/app/3073940/God_Save_Birmingham/",
                image: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/3073940/header.jpg",
                accent: "#D97706",
                descEN: "Public Beta 2 of the medieval zombie survival game, adding four-player co-op. Everyone who requests access gets in, with no NDA.",
                descDE: "\u{00D6}ffentliche Beta 2 des mittelalterlichen Zombie-Survival-Spiels: Neu ist der Koop-Modus f\u{00FC}r bis zu vier Spieler. Wer Zugang anfordert, kommt rein, ganz ohne NDA.",
                tags: ["Survival", "Zombies", "Co-op"]
            ),
            PlaytestItem(
                id: "soulframe",
                title: "Soulframe \u{2014} Open Preludes",
                platform: "PC",
                status: "Signups open",
                deadline: nil,
                url: "https://soulframe.com",
                image: "https://www-static.soulframe.com/images/opengraph-image6.jpg",
                accent: "#C9A86A",
                descEN: "Digital Extremes (Warframe) opens its fantasy RPG alpha to everyone: a free account on soulframe.com plus the standalone launcher is all you need \u{2014} no key required.",
                descDE: "Digital Extremes (Warframe) \u{00F6}ffnet die Alpha seines Fantasy-RPGs f\u{00FC}r alle: Ein kostenloser Account auf soulframe.com plus der eigene Launcher reichen \u{2013} kein Key mehr n\u{00F6}tig.",
                tags: ["RPG", "Alpha", "Free"]
            ),
            PlaytestItem(
                id: "escape-from-playtime",
                title: "Escape From Playtime",
                platform: "Steam",
                status: "Ended",
                deadline: nil,
                url: "https://store.steampowered.com/app/2087540/Escape_from_Playtime/",
                image: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2087540/89c440a7eda7dc33db8233c8d843f7e1f85af0da/header_alt_assets_0.jpg",
                accent: "#E11D48",
                descEN: "The playtest is over: the open beta ran in early October, and Mob Entertainment's co-op horror game has been out in Steam Early Access since October 21, 2026 ($9.99).",
                descDE: "Der Playtest ist vorbei: Die Open Beta lief Anfang Oktober, seit dem 21. Oktober 2026 ist das Co-op-Horror-Spiel von Mob Entertainment im Early Access auf Steam erh\u{00E4}ltlich (9,99 $).",
                tags: ["Horror", "Co-op", "Released"]
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
