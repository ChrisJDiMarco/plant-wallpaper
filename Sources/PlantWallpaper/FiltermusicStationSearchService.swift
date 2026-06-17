import Foundation
import PlantGardenCore

struct FiltermusicStationSearchService {
    static let shared = FiltermusicStationSearchService()

    private static let sitemapURL = URL(string: "https://filtermusic.net/sitemap-0.xml")!
    private static let ignoredSlugs: Set<String> = [
        "",
        "changelog",
        "contact",
        "credits",
        "design",
        "favorites",
        "frequently-asked-questions",
        "graphics-and-logos",
        "support",
        "technical-details",
        "terms-and-conditions",
        "thank-you-for-your-donation"
    ]

    func search(query: String, limit: Int = 18) async -> [GardenRadioStream] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let builtIns = GardenRadioStation.allCases.map(\.stream)
        let localMatches = builtIns.filter { stream in
            normalizedQuery.isEmpty
                || stream.displayName.lowercased().contains(normalizedQuery)
                || stream.shortDescription.lowercased().contains(normalizedQuery)
                || stream.filtermusicPageURLString?.lowercased().contains(normalizedQuery) == true
        }

        guard let slugs = await fetchSitemapSlugs() else {
            return Array(localMatches.prefix(limit))
        }

        let matchedSlugs = slugs
            .filter { slug in
                normalizedQuery.isEmpty
                    || slug.replacingOccurrences(of: "-", with: " ").contains(normalizedQuery)
                    || slug.contains(normalizedQuery)
            }
            .filter { slug in
                !builtIns.contains { $0.filtermusicPageURLString?.hasSuffix("/\(slug)") == true }
            }
            .prefix(max(0, limit - localMatches.count))

        var liveMatches = [GardenRadioStream]()
        for slug in matchedSlugs {
            if let stream = await fetchStation(slug: slug) {
                liveMatches.append(stream)
            }
        }

        return Array((localMatches + liveMatches).prefix(limit))
    }

    private func fetchSitemapSlugs() async -> [String]? {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.sitemapURL)
            guard let xml = String(data: data, encoding: .utf8) else {
                return nil
            }
            return Self.extractURLs(from: xml)
                .compactMap { urlString -> String? in
                    guard let url = URL(string: urlString),
                          url.host?.lowercased() == "filtermusic.net" else {
                        return nil
                    }
                    let slug = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
                    return Self.ignoredSlugs.contains(slug) ? nil : slug
                }
        } catch {
            NSLog("Plant Wallpaper could not search Filtermusic sitemap: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchStation(slug: String) async -> GardenRadioStream? {
        guard let url = URL(string: "https://filtermusic.net/\(slug)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8),
                  html.contains("radio-info"),
                  let listen = Self.attribute("data-listen", in: html),
                  !listen.isEmpty else {
                return nil
            }

            let title = Self.attribute("data-title", in: html)
                ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
            let category = Self.attribute("data-category", in: html) ?? ""
            let summary = Self.metaDescription(in: html) ?? ""
            return GardenRadioStream.filtermusic(
                slug: slug,
                title: Self.decodeHTMLEntities(title),
                listenURLString: listen,
                category: Self.decodeHTMLEntities(category),
                summary: Self.decodeHTMLEntities(summary)
            )
        } catch {
            NSLog("Plant Wallpaper could not load Filtermusic station \(slug): \(error.localizedDescription)")
            return nil
        }
    }

    private static func extractURLs(from xml: String) -> [String] {
        matches(pattern: #"<loc>(.*?)</loc>"#, in: xml).map { decodeHTMLEntities($0) }
    }

    private static func attribute(_ name: String, in html: String) -> String? {
        matches(pattern: #"\#(name)="([^"]*)""#, in: html).first.map(decodeHTMLEntities)
    }

    private static func metaDescription(in html: String) -> String? {
        matches(pattern: #"<meta name="description" content="([^"]*)""#, in: html).first
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
