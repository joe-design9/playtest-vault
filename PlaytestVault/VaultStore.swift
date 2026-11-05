import Foundation

/// Personal vault entries, persisted as JSON in UserDefaults under
/// "vault.entries.v1". Seeded once on first launch with real entries.
@MainActor
final class VaultStore: ObservableObject {
    @Published var entries: [VaultEntry] = []

    private static let entriesKey = "vault.entries.v1"
    private static let seededKey = "vault.seeded.v1"

    private let uiTestMode: Bool

    init(uiTestMode: Bool) {
        self.uiTestMode = uiTestMode
        if uiTestMode {
            entries = Self.sampleEntries()
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.entriesKey),
           let decoded = try? Self.decoder.decode([VaultEntry].self, from: data) {
            entries = decoded
        } else if !UserDefaults.standard.bool(forKey: Self.seededKey) {
            entries = Self.seedEntries()
            UserDefaults.standard.set(true, forKey: Self.seededKey)
            persist()
        }
    }

    /// Entries with deadlines first (earliest deadline first), then the
    /// rest by newest added.
    var sortedEntries: [VaultEntry] {
        entries.sorted { a, b in
            switch (a.deadline, b.deadline) {
            case let (da?, db?): return da < db
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.dateAdded > b.dateAdded
            }
        }
    }

    func contains(title: String) -> Bool {
        entries.contains { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    func add(_ entry: VaultEntry) {
        entries.append(entry)
        persist()
    }

    @discardableResult
    func addFromDiscover(_ item: PlaytestItem) -> Bool {
        guard !contains(title: item.title) else { return false }
        let source: String
        switch item.platform {
        case "Steam": source = "steam"
        case "FirstLook": source = "firstlook"
        case "player.gg": source = "playergg"
        default: source = "discover"
        }
        let status: VaultStatus
        switch item.status {
        case "Live now": status = .access
        case "Ended": status = .done
        default: status = .discovered
        }
        add(VaultEntry(title: item.title, platform: item.platform, source: source,
                       status: status, deadline: item.deadline, notes: ""))
        return true
    }

    @discardableResult
    func addFromDemo(_ demo: SteamDemo) -> Bool {
        guard !contains(title: demo.title) else { return false }
        add(VaultEntry(title: demo.title, platform: "Steam", source: "steam",
                       status: .discovered, notes: ""))
        return true
    }

    func update(_ entry: VaultEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        persist()
    }

    func delete(_ entry: VaultEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func delete(atOffsets offsets: IndexSet, from sorted: [VaultEntry]) {
        for offset in offsets { delete(sorted[offset]) }
    }

    private func persist() {
        guard !uiTestMode else { return }
        if let data = try? Self.encoder.encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
        }
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Seeds

    /// First-launch seeds: the real playtests already in progress.
    /// Notes follow the app language at seed time.
    private static func seedEntries() -> [VaultEntry] {
        let now = Date()
        return [
            VaultEntry(
                title: "Fantum's Peak-like Game (Playtest)",
                platform: "Steam", source: "steam", status: .access,
                notes: Lang.tr("Steam-Key erhalten, erneut ausgewählt", "Steam key received, picked again for the next playtest"),
                dateAdded: now
            ),
            VaultEntry(
                title: "Project SCOOP (DIG SIMULATOR)",
                platform: "FirstLook", source: "firstlook", status: .done,
                notes: Lang.tr("Abschluss-Umfrage war der letzte Schritt", "The closing survey was the final step"),
                dateAdded: now
            ),
            VaultEntry(
                title: "Escape From Playtime",
                platform: "Steam", source: "steam", status: .applied,
                notes: Lang.tr("Early Access 8,99 \u{20AC}, Test & ggf. Refund geplant", "Early Access EUR 8.99, test & refund planned if needed"),
                dateAdded: now
            ),
            VaultEntry(
                title: "players.gg Bewerbungen",
                platform: "player.gg", source: "playergg", status: .applied,
                notes: Lang.tr("Für zufällige Playtests beworben", "Applied for random playtests"),
                dateAdded: now
            ),
        ]
    }

    /// Three demo entries for -UITestMode screenshots (never persisted).
    private static func sampleEntries() -> [VaultEntry] {
        let now = Date()
        return [
            VaultEntry(
                title: "Fantum's Peak-like Game (Playtest)",
                platform: "Steam", source: "steam", status: .access,
                notes: Lang.tr("Steam-Key erhalten, erneut ausgewählt", "Steam key received, picked again"),
                dateAdded: now
            ),
            VaultEntry(
                title: "Mecha Arena — Playtest",
                platform: "Steam", source: "steam", status: .surveyOpen,
                deadline: now.addingTimeInterval(26 * 3600),
                notes: Lang.tr("Umfrage nach dem Wochenende ausfüllen", "Fill in the survey after the weekend"),
                dateAdded: now
            ),
            VaultEntry(
                title: "Project SCOOP (DIG SIMULATOR)",
                platform: "FirstLook", source: "firstlook", status: .done,
                notes: Lang.tr("Abschluss-Umfrage war der letzte Schritt", "The closing survey was the final step"),
                dateAdded: now
            ),
        ]
    }
}
