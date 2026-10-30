import Foundation

/// Strips known tracking query parameters from URLs found in shared text.
///
/// Swift port of Android's `UrlCleaner.kt`. The rules both share live in shared/rules/rules.json.
public enum UrlCleaner {

    private static let urlRegex = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)

    // The rules themselves (tracking params, prefixes, site-specific params) live in
    // shared/rules/rules.json and are generated into GeneratedRules.swift.

    private static func isTrackingParam(_ name: String, host: String?) -> Bool {
        if GeneratedRules.trackingPrefixes.contains(where: { name.hasPrefix($0) }) || GeneratedRules.trackingParams.contains(name) {
            return true
        }
        guard let lowerHost = host?.lowercased() else { return false }
        return GeneratedRules.siteParams.contains { domain, params in
            params.contains(name) && hostMatches(lowerHost, domain)
        }
    }

    /// True if `host` is `domain` or one of its subdomains. A `domain` ending in ".*" (e.g.
    /// "eventbrite.*") instead matches that name followed by a country ending: "com", a two-letter
    /// country code, or "com."/"co." plus one (so eventbrite.com, eventbrite.ca, eventbrite.com.au,
    /// eventbrite.co.uk), plus subdomains of those. Lookalikes like noteventbrite.com or
    /// eventbrite.evil.com don't match.
    private static func hostMatches(_ host: String, _ domain: String) -> Bool {
        guard domain.hasSuffix(".*") else { return host == domain || host.hasSuffix(".\(domain)") }
        let name = NSRegularExpression.escapedPattern(for: String(domain.dropLast(2)))
        let pattern = #"^(.+\.)?"# + name + #"\.(com|[a-z]{2}|(com|co)\.[a-z]{2})$"#
        return host.range(of: pattern, options: .regularExpression) != nil
    }

    /// The first http(s) URL found in some text, and where it sits within that text.
    public struct UrlMatch: Equatable, Sendable {
        public let range: Range<String.Index>
        public let url: String
    }

    /// Returns the first http(s) URL found in `text` along with its range, or nil if none is present.
    public static func findFirstUrl(in text: String) -> UrlMatch? {
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = urlRegex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text)
        else { return nil }
        return UrlMatch(range: range, url: String(text[range]))
    }

    /// Finds the first http(s) URL in `text` and returns `text` with that URL's tracking
    /// query parameters removed. If no URL is found, returns `text` unchanged.
    public static func cleanFirstUrl(in text: String) -> String {
        guard let match = findFirstUrl(in: text), let cleaned = cleanUrl(match.url) else { return text }
        return text.replacingCharacters(in: match.range, with: cleaned)
    }

    /// Removes tracking query parameters from a single URL string, preserving any
    /// non-tracking query parameters and the fragment. Returns nil if the URL can't be parsed.
    ///
    /// Works on the raw string rather than rebuilding from parsed components, so everything
    /// other than the removed params (percent-encoding, param order, the fragment) is kept
    /// byte-for-byte.
    public static func cleanUrl(_ url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }

        var beforeFragment = Substring(url)
        var fragment: Substring?
        if let hashIndex = url.firstIndex(of: "#") {
            beforeFragment = url[..<hashIndex]
            fragment = url[url.index(after: hashIndex)...]
        }

        guard let questionIndex = beforeFragment.firstIndex(of: "?") else { return url }
        let base = beforeFragment[..<questionIndex]
        let rawQuery = beforeFragment[beforeFragment.index(after: questionIndex)...]

        let keptPairs = rawQuery.split(separator: "&", omittingEmptySubsequences: true).filter { pair in
            let name = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            return !isTrackingParam(String(name), host: components.host)
        }

        var result = String(base)
        if !keptPairs.isEmpty { result += "?" + keptPairs.joined(separator: "&") }
        if let fragment { result += "#" + fragment }
        return result
    }
}
