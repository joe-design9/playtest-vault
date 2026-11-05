import Foundation

enum DemoSort {
    case new
    case popular

    var queryValue: String {
        switch self {
        case .new: return "Released_DESC"
        case .popular: return "_ASC"
        }
    }
}

/// Live Steam demo discovery: the store search endpoint (category1=10
/// = demos) returns JSON with an HTML payload that we parse into rows.
enum SteamService {
    static func searchURL(sort: DemoSort) -> URL {
        var components = URLComponents(string: "https://store.steampowered.com/search/results/")!
        components.queryItems = [
            URLQueryItem(name: "query", value: ""),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "count", value: "50"),
            URLQueryItem(name: "dynamic_data", value: ""),
            URLQueryItem(name: "sort_by", value: sort.queryValue),
            URLQueryItem(name: "force_infinite", value: "1"),
            URLQueryItem(name: "category1", value: "10"),
            URLQueryItem(name: "infinite", value: "1"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "cc", value: "de"),
            URLQueryItem(name: "l", value: Lang.steamLanguage),
        ]
        // The search endpoint expects a bare "query" flag without "=".
        var url = components.url!
        url = URL(string: url.absoluteString.replacingOccurrences(of: "query=&", with: "query&")) ?? url
        return url
    }

    static func fetchDemos(sort: DemoSort) async throws -> [SteamDemo] {
        let data = try await HTTP.get(searchURL(sort: sort))
        let payload = try JSONDecoder().decode(SearchPayload.self, from: data)
        return parseResultsHTML(payload.resultsHTML)
    }

    private struct SearchPayload: Decodable {
        var resultsHTML: String
        var totalCount: Int?

        private enum CodingKeys: String, CodingKey {
            case resultsHTML = "results_html"
            case totalCount = "total_count"
        }
    }

    /// Each result row carries data-ds-appid (the DEMO app id), an href
    /// to /app/<full game id>/<slug>/ and a span.title with the name.
    static func parseResultsHTML(_ html: String) -> [SteamDemo] {
        var demos: [SteamDemo] = []
        var seen = Set<Int>()
        let chunks = html.components(separatedBy: "search_result_row")
        for chunk in chunks.dropFirst() {
            guard let demoID = firstInt(pattern: "data-ds-appid=\"([0-9]+)", in: chunk),
                  let fullID = firstInt(pattern: "href=\"https://store\\.steampowered\\.com/app/([0-9]+)/", in: chunk),
                  let rawTitle = firstCapture(pattern: "<span class=\"title\">(.*?)</span>", in: chunk)
            else { continue }
            guard !seen.contains(demoID) else { continue }
            seen.insert(demoID)
            let title = TextTools.stripHTML(rawTitle)
            guard !title.isEmpty else { continue }
            demos.append(SteamDemo(demoAppID: demoID, fullGameID: fullID, title: title))
        }
        return demos
    }

    static func fetchDetails(fullGameID: Int) async throws -> SteamGameDetails {
        var components = URLComponents(string: "https://store.steampowered.com/api/appdetails")!
        components.queryItems = [
            URLQueryItem(name: "appids", value: String(fullGameID)),
            URLQueryItem(name: "cc", value: "de"),
            URLQueryItem(name: "l", value: Lang.steamLanguage),
        ]
        let data = try await HTTP.get(components.url!)
        let decoded = try JSONDecoder().decode([String: AppDetailEntry].self, from: data)
        guard let entry = decoded[String(fullGameID)], entry.success, let app = entry.data else {
            throw URLError(.cannotParseResponse)
        }
        return SteamGameDetails(
            name: app.name,
            headerImage: app.headerImage.flatMap { URL(string: $0) },
            shortDescription: TextTools.stripHTML(app.shortDescription ?? ""),
            genres: (app.genres ?? []).map { $0.description }.filter { !$0.isEmpty },
            releaseDate: app.releaseDate?.date ?? ""
        )
    }

    private struct AppDetailEntry: Decodable {
        var success: Bool
        var data: AppData?
    }

    private struct AppData: Decodable {
        var name: String
        var headerImage: String?
        var shortDescription: String?
        var genres: [Genre]?
        var releaseDate: ReleaseDate?

        private enum CodingKeys: String, CodingKey {
            case name, genres
            case headerImage = "header_image"
            case shortDescription = "short_description"
            case releaseDate = "release_date"
        }
    }

    private struct Genre: Decodable {
        var description: String
    }

    private struct ReleaseDate: Decodable {
        var date: String?
    }

    // MARK: - Regex helpers

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func firstInt(pattern: String, in text: String) -> Int? {
        firstCapture(pattern: pattern, in: text).flatMap { Int($0) }
    }
}

/// Small text helpers: HTML tag stripping and entity decoding, used for
/// Steam search titles and appdetails short descriptions.
enum TextTools {
    static func stripHTML(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n")
        text = text.replacingOccurrences(of: "<br />", with: "\n")
        text = text.replacingOccurrences(of: "</p>", with: "\n\n")
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        text = decodeEntities(text)
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        var result = text
        let named: [(String, String)] = [
            ("&amp;", "&"), ("&quot;", "\""), ("&apos;", "'"),
            ("&#39;", "'"), ("&#039;", "'"), ("&lt;", "<"), ("&gt;", ">"),
            ("&nbsp;", " "), ("&hellip;", "\u{2026}"), ("&ndash;", "\u{2013}"),
            ("&mdash;", "\u{2014}"), ("&reg;", "\u{00AE}"), ("&trade;", "\u{2122}"),
            ("&copy;", "\u{00A9}"),
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Numeric entities (&#123; / &#x1F;).
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);", options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let numRange = Range(match.range(at: 1), in: result) else { continue }
                let digits = String(result[numRange])
                let value: UInt32?
                if digits.hasPrefix("x") || digits.hasPrefix("X") {
                    value = UInt32(digits.dropFirst(), radix: 16)
                } else {
                    value = UInt32(digits, radix: 10)
                }
                if let value, let scalar = UnicodeScalar(value) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        return result
    }
}
