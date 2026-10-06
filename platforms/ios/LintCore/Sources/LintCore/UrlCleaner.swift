import Foundation

/// Strips known tracking query parameters from URLs found in shared text.
///
/// Swift port of Android's `UrlCleaner.kt` -- the param lists below must stay in sync with it.
public enum UrlCleaner {

    private static let urlRegex = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)

    private static let exactTrackingParams: Set<String> = [
        // Original set
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid",
        "igshid", "igsh", "twclid", "ttclid", "yclid",
        "vero_id", "vero_conv",
        "mc_cid", "mc_eid",
        "mkt_tok", "_hsenc", "_hsmi",
        // Not "cid": generic enough that Google Maps uses it to identify a place (?cid=…), so
        // stripping it broke shared Maps links, and there's no single site to scope it to.
        "ref", "ref_src", "epik",
        // Google (Ads/Analytics/Shopping)
        "aqs", "cd", "ei", "iflsig", "pcampaignid", "rlz", "srsltid", "sxsrf", "uact", "ved",
        "_ga", "_gl",
        // Meta/Facebook
        "comment_tracking", "eav", "mibextid", "__tn__",
        // Snapchat
        "ScCid",
        // Reddit
        "correlation_id", "rdt", "ref_campaign", "ref_source", "share_id",
        // LinkedIn
        "refId", "trackingId", "trk",
        // Amazon
        "ascsubtag", "camp", "creative", "dchild", "qid", "refRID", "smid", "spIA", "srs",
        // HubSpot / marketing
        "__hsfp", "__hssc", "__hstc",
        // Twitter/X
        "__twitter_impression",
        // Matomo/Piwik legacy exact params (not a blanket "pk_*"/"piwik_*" prefix — those are too
        // generic and collide with ordinary app query params like "?pk_id=42")
        "pk_campaign", "pk_kwd", "pk_keyword", "pk_medium", "pk_source", "pk_content", "pk_cid",
        "piwik_campaign", "piwik_kwd",
    ]

    /// Tracking params that are only stripped on specific sites, because their names are generic
    /// enough that some unrelated site could plausibly rely on them (e.g. "?feature=" as a feature
    /// flag, "?_t=" as a tab or token). Breaking a link is worse than leaving a tracker in, so
    /// anything that isn't unambiguously a tracker goes here rather than in
    /// `exactTrackingParams`. Keys match the host itself and any of its subdomains.
    private static let hostScopedTrackingParams: [String: Set<String>] = [
        // YouTube: "feature" marks that a video was reached via a youtu.be short link; "si" is
        // the per-share token identifying who shared it.
        "youtube.com": ["feature", "si"],
        "youtu.be": ["feature", "si"],
        // Spotify: "si" is the per-share token identifying who shared it.
        "spotify.com": ["si"],
        // Meta/Facebook: "eid" is a Facebook tracking param, but Google Calendar uses ?eid= to
        // identify an event, so it's only stripped on Facebook.
        "facebook.com": ["eid"],
        // TikTok: appended to a video URL once a vm.tiktok.com/vt.tiktok.com share link
        // resolves, identifying the sharer's device/session and how the link was copied.
        "tiktok.com": [
            "is_from_webapp", "sender_device", "web_id",
            "share_app_id", "share_link_id", "share_item_id", "u_code", "_r", "_t",
        ],
    ]

    private static let trackingPrefixes = ["utm_", "mtm_"]

    private static func isTrackingParam(_ name: String, host: String?) -> Bool {
        if trackingPrefixes.contains(where: { name.hasPrefix($0) }) || exactTrackingParams.contains(name) {
            return true
        }
        guard let lowerHost = host?.lowercased() else { return false }
        return hostScopedTrackingParams.contains { domain, params in
            (lowerHost == domain || lowerHost.hasSuffix(".\(domain)")) && params.contains(name)
        }
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
