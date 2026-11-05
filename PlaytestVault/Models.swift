import Foundation
import SwiftUI

/// App language (German/English). Stored in UserDefaults under
/// "appLanguage" as a full locale code ("de_DE" / "en_US"), mirroring
/// the Hub's Lang pattern. Default: device language (German if the
/// device is German, English otherwise).
enum Lang {
    static var code: String {
        if let stored = UserDefaults.standard.string(forKey: "appLanguage"), !stored.isEmpty {
            return stored
        }
        let device = Locale.current.language.languageCode?.identifier ?? "en"
        return device == "de" ? "de_DE" : "en_US"
    }

    static var isEN: Bool { !code.hasPrefix("de") }
    static var locale: Locale { Locale(identifier: code) }
    static func tr(_ de: String, _ en: String) -> String { isEN ? en : de }

    /// Steam store language parameter ("german" / "en").
    static var steamLanguage: String { isEN ? "en" : "german" }
}

/// Lenient ISO-8601 date parsing for feed JSON (with/without fractional
/// seconds, plus a plain yyyy-MM-dd fallback).
enum DateParser {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? plain.date(from: value) ?? dayOnly.date(from: value)
    }

    static func string(_ date: Date) -> String { plain.string(from: date) }
}

/// Deadline countdown wording shared by feed cards, vault cards and
/// the detail views.
enum Countdown {
    static func chipText(deadline: Date, now: Date = Date()) -> String {
        let seconds = deadline.timeIntervalSince(now)
        if seconds <= 0 { return Lang.tr("Beendet", "Ended") }
        if seconds < 48 * 3600 {
            let hours = max(1, Int(ceil(seconds / 3600)))
            return Lang.tr("noch \(hours) Std.", "\(hours) h left")
        }
        let days = Int(ceil(seconds / 86400))
        if days == 1 { return Lang.tr("noch 1 Tag", "1 day left") }
        return Lang.tr("noch \(days) Tage", "\(days) days left")
    }

    /// Red chip state: less than 48 hours to go (but not yet over).
    static func isUrgent(deadline: Date, now: Date = Date()) -> Bool {
        let seconds = deadline.timeIntervalSince(now)
        return seconds > 0 && seconds < 48 * 3600
    }

    static func detailText(deadline: Date, now: Date = Date()) -> String {
        let seconds = deadline.timeIntervalSince(now)
        let formatter = DateFormatter()
        formatter.locale = Lang.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateText = formatter.string(from: deadline)
        if seconds <= 0 {
            return Lang.tr("Frist abgelaufen (\(dateText))", "Deadline passed (\(dateText))")
        }
        let totalHours = Int(seconds) / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        let left: String
        if days > 0 {
            left = Lang.tr("\(days) Tage, \(hours) Std. übrig", "\(days) days, \(hours) hours left")
        } else if hours > 0 {
            left = Lang.tr("\(hours) Std. übrig", "\(hours) hours left")
        } else {
            let minutes = max(1, Int(seconds) / 60)
            left = Lang.tr("\(minutes) Min. übrig", "\(minutes) min left")
        }
        return "\(left) \u{00B7} \(dateText)"
    }
}

// MARK: - Discover feed (remote playtests.json)

struct PlaytestItem: Identifiable, Equatable {
    var id: String
    var title: String
    var platform: String
    var status: String
    var deadline: Date?
    var url: String
    var image: String?
    var descEN: String
    var descDE: String
    var tags: [String]

    var pageURL: URL? { URL(string: url) }
    var imageURL: URL? { image.flatMap { URL(string: $0) } }
    var description: String { Lang.isEN ? descEN : descDE }
}

extension PlaytestItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, platform, status, deadline, url, image, tags
        case descEN = "desc_en"
        case descDE = "desc_de"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        platform = try c.decode(String.self, forKey: .platform)
        status = try c.decode(String.self, forKey: .status)
        if let raw = try c.decodeIfPresent(String.self, forKey: .deadline) {
            deadline = DateParser.parse(raw)
        } else {
            deadline = nil
        }
        url = try c.decode(String.self, forKey: .url)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        descEN = try c.decode(String.self, forKey: .descEN)
        descDE = try c.decode(String.self, forKey: .descDE)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(platform, forKey: .platform)
        try c.encode(status, forKey: .status)
        if let deadline {
            try c.encode(DateParser.string(deadline), forKey: .deadline)
        } else {
            try c.encodeNil(forKey: .deadline)
        }
        try c.encode(url, forKey: .url)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encode(descEN, forKey: .descEN)
        try c.encode(descDE, forKey: .descDE)
        try c.encode(tags, forKey: .tags)
    }
}

struct PlaytestFeed: Codable, Equatable {
    var updated: String
    var playtests: [PlaytestItem]

    var updatedDate: Date? { DateParser.parse(updated) }
}

// MARK: - Vault

enum VaultStatus: String, Codable, CaseIterable, Identifiable {
    case discovered
    case applied
    case access
    case keyReceived
    case playing
    case surveyOpen
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discovered: return Lang.tr("Entdeckt", "Discovered")
        case .applied: return Lang.tr("Beworben", "Applied")
        case .access: return Lang.tr("Zugang", "Access")
        case .keyReceived: return Lang.tr("Key erhalten", "Key received")
        case .playing: return Lang.tr("Spielt gerade", "Playing")
        case .surveyOpen: return Lang.tr("Umfrage offen", "Survey open")
        case .done: return Lang.tr("Abgeschlossen", "Done")
        }
    }

    var color: Color {
        switch self {
        case .discovered: return Color(red: 0.35, green: 0.65, blue: 1.0)
        case .applied: return Color(red: 1.0, green: 0.62, blue: 0.25)
        case .access: return VaultAccent.teal
        case .keyReceived: return Color(red: 0.35, green: 0.85, blue: 0.45)
        case .playing: return Color(red: 0.70, green: 0.50, blue: 1.0)
        case .surveyOpen: return Color(red: 1.0, green: 0.42, blue: 0.60)
        case .done: return Color(red: 0.62, green: 0.62, blue: 0.66)
        }
    }
}

struct VaultEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var platform: String
    var source: String
    var status: VaultStatus
    var deadline: Date?
    var notes: String
    var dateAdded: Date

    init(id: UUID = UUID(), title: String, platform: String, source: String,
         status: VaultStatus, deadline: Date? = nil, notes: String = "",
         dateAdded: Date = Date()) {
        self.id = id
        self.title = title
        self.platform = platform
        self.source = source
        self.status = status
        self.deadline = deadline
        self.notes = notes
        self.dateAdded = dateAdded
    }
}

/// Platforms offered in the entry editor.
enum Platforms {
    static let all = ["Steam", "FirstLook", "player.gg", "Xbox", "PlayStation", "Switch", "Other"]
}

// MARK: - Steam demos

struct SteamDemo: Identifiable, Equatable {
    /// The demo's own app id (from data-ds-appid) — used for images.
    var demoAppID: Int
    /// The full game's app id (from the row href) — used for appdetails.
    var fullGameID: Int
    var title: String

    var id: Int { demoAppID }

    var capsuleURL: URL? {
        URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(demoAppID)/capsule_231x87.jpg")
    }

    var headerURL: URL? {
        URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(demoAppID)/header.jpg")
    }

    /// Public store page of the demo itself.
    var storeURL: URL? { URL(string: "https://store.steampowered.com/app/\(demoAppID)/") }
}

struct SteamGameDetails: Equatable {
    var name: String
    var headerImage: URL?
    var shortDescription: String
    var genres: [String]
    var releaseDate: String
}
