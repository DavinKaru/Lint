import Foundation

/// Strips known tracking query parameters from URLs found in shared text, after unwrapping any
/// known redirect link (e.g. google.com/url?q=...) to the real link inside it.
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
    static func hostMatches(_ host: String, _ domain: String) -> Bool {
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

    /// Unwraps known redirect links (Gmail's google.com/url?q=..., l.facebook.com/l.php?u=...,
    /// Outlook Safe Links, ...) to the real link they point at, entirely offline. Wrappers inside
    /// wrappers are unwrapped too. Anything that isn't a known wrapper with a valid http(s) link
    /// inside is returned unchanged.
    public static func unwrap(_ url: String) -> String {
        var current = url
        for _ in 0..<maxUnwrapDepth {
            guard let next = unwrapOnce(current) else { return current }
            current = next
        }
        return current
    }

    private static let maxUnwrapDepth = 5

    private static func unwrapOnce(_ url: String) -> String? {
        guard let components = URLComponents(string: url), let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath

        for wrapper in GeneratedRules.pathWrappers {
            guard wrapper.sites.contains(where: { hostMatches(host, $0) }), path.hasPrefix(wrapper.prefix) else { continue }
            var rest = String(path.dropFirst(wrapper.prefix.count))
            if let query = components.percentEncodedQuery { rest += "?" + query }
            if let fragment = components.percentEncodedFragment { rest += "#" + fragment }
            return validTarget(wrapper.scheme + "://" + rest)
        }

        guard let query = components.percentEncodedQuery else { return nil }
        let pairs = query.split(separator: "&", omittingEmptySubsequences: true).map(String.init)
        for wrapper in GeneratedRules.redirectWrappers {
            guard wrapper.sites.contains(where: { hostMatches(host, $0) }),
                  wrapper.paths.contains(where: { pathMatches(path, $0) })
            else { continue }
            for param in wrapper.params {
                guard let pair = pairs.first(where: { $0.hasPrefix(param + "=") }) else { continue }
                let value = String(pair.dropFirst(param.count + 1))
                let decoded = wrapper.base64Prefix.map { base64UrlDecode(value, prefix: $0) } ?? percentDecode(value)
                guard let target = decoded else { continue }
                if let valid = validTarget(target) { return valid }
            }
        }
        return nil
    }

    private static func pathMatches(_ path: String, _ pattern: String) -> Bool {
        pattern.hasSuffix("*") ? path.hasPrefix(String(pattern.dropLast())) : path == pattern
    }

    /// `target` if it's an http(s) link that parses with a host, otherwise nil.
    private static func validTarget(_ target: String) -> String? {
        let lower = target.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return nil }
        guard !target.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) })
        else { return nil }
        guard let host = URLComponents(string: target)?.host, !host.isEmpty else { return nil }
        return target
    }

    /// Decodes `value` if it's `prefix` followed by unpadded base64url (Bing's u=a1aHR0c... form), or
    /// nil if it isn't or the bytes aren't valid UTF-8. Never falls back to percent-decoding: a
    /// wrapper that uses base64 always does.
    private static func base64UrlDecode(_ value: String, prefix: String) -> String? {
        guard value.hasPrefix(prefix) else { return nil }
        var body = String(value.dropFirst(prefix.count))
        while body.hasSuffix("=") { body.removeLast() }
        guard body.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              body.count % 4 != 1
        else { return nil }
        var standard = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        standard += String(repeating: "=", count: (4 - standard.count % 4) % 4)
        guard let data = Data(base64Encoded: standard) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Strict percent-decoding ("+" stays "+"): nil if malformed or not valid UTF-8.
    private static func percentDecode(_ value: String) -> String? {
        let utf8 = Array(value.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(utf8.count)
        var i = 0
        while i < utf8.count {
            if utf8[i] == UInt8(ascii: "%") {
                guard i + 2 < utf8.count, let hi = hexValue(utf8[i + 1]), let lo = hexValue(utf8[i + 2]) else { return nil }
                bytes.append(hi << 4 | lo)
                i += 3
            } else {
                bytes.append(utf8[i])
                i += 1
            }
        }
        return String(bytes: bytes, encoding: .utf8)
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        default: nil
        }
    }

    /// Unwraps `url` if it's a known redirect link (see `unwrap`), then removes tracking query
    /// parameters, preserving any non-tracking query parameters and the fragment. Returns nil if
    /// the URL can't be parsed.
    ///
    /// Works on the raw string rather than rebuilding from parsed components, so everything
    /// other than the removed params (percent-encoding, param order, the fragment) is kept
    /// byte-for-byte.
    public static func cleanUrl(_ original: String) -> String? {
        let url = unwrap(original)
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
