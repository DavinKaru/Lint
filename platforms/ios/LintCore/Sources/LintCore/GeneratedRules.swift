// Generated from shared/rules/rules.json by shared/rules/generate.py. Don't edit by hand.

enum GeneratedRules {

    /// Params starting with any of these are stripped on every site.
    static let trackingPrefixes: [String] = [
        // Google Analytics campaign tags (used everywhere)
        "utm_",
        // Matomo campaign tags
        "mtm_",
        // Secret Media Network (Secret Melbourne, Secret London, ...)
        //   Campaign tags it adds to partner links, e.g. Fever tickets (cp_smn_source, cp_smn_content, cp_smn_term). Distinctive enough to strip on every site, like utm_.
        "cp_smn_",
    ]

    /// Params stripped on every site.
    static let trackingParams: Set<String> = [
        // Ad and social click IDs
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid", "igshid", "igsh", "twclid", "ttclid", "yclid",
        // Vero
        "vero_id", "vero_conv",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Marketo
        "mkt_tok",
        // HubSpot
        "_hsenc", "_hsmi", "__hsfp", "__hssc", "__hstc",
        // Generic referral
        //   Generic names, under review in #15.
        "ref", "ref_src",
        // Pinterest
        "epik",
        // Google (Ads, Analytics, Search, Shopping)
        //   cd and ei are generic names, under review in #15.
        "aqs", "cd", "ei", "iflsig", "pcampaignid", "rlz", "srsltid", "sxsrf", "uact", "ved", "_ga", "_gl",
        // Meta / Facebook
        //   eid is Facebook-only, see siteParams.
        "comment_tracking", "eav", "mibextid", "__tn__",
        // Snapchat
        "ScCid",
        // Reddit
        //   share_id is a generic name, under review in #15.
        "correlation_id", "rdt", "ref_campaign", "ref_source", "share_id",
        // LinkedIn
        //   Generic names, under review in #15.
        "refId", "trackingId", "trk",
        // Amazon
        //   camp, creative, qid, smid and srs are generic names, under review in #15.
        "ascsubtag", "camp", "creative", "dchild", "qid", "refRID", "smid", "spIA", "srs",
        // Twitter / X
        "__twitter_impression",
        // Matomo / Piwik (legacy)
        //   Exact names only: a blanket pk_* or piwik_* prefix would hit ordinary params like ?pk_id=42.
        "pk_campaign", "pk_kwd", "pk_keyword", "pk_medium", "pk_source", "pk_content", "pk_cid", "piwik_campaign", "piwik_kwd",
    ]

    /// Params only stripped on specific sites, because their names are generic enough to mean
    /// something real elsewhere. Keys match the host and its subdomains; a key ending in ".*"
    /// matches that name on any country domain (see `UrlCleaner.hostMatches`).
    static let siteParams: [String: Set<String>] = [
        // YouTube
        //   feature marks a video reached via a youtu.be short link; si is the per-share token identifying who shared it.
        "youtube.com": ["feature", "si"],
        "youtu.be": ["feature", "si"],
        // Spotify
        //   si is the per-share token identifying who shared it.
        "spotify.com": ["si"],
        // Meta / Facebook
        //   eid is a Facebook tracking param, but Google Calendar uses ?eid= to identify an event (#2), so it's only stripped on Facebook.
        "facebook.com": ["eid"],
        // Eventbrite
        //   aff records how a link was shared (e.g. ebdsshandroid, ebdsshsms); sg is a long per-share token. Eventbrite uses a domain per country, hence the wildcard.
        "eventbrite.*": ["aff", "sg"],
        // Fever
        //   suid looks like a per-user/session ID on shared event links.
        "feverup.com": ["suid"],
        // TikTok
        //   Appended once a vm.tiktok.com/vt.tiktok.com share link resolves, identifying the sharer's device/session and how the link was copied.
        "tiktok.com": ["is_from_webapp", "sender_device", "web_id", "share_app_id", "share_link_id", "share_item_id", "u_code", "_r", "_t"],
    ]

    /// Hosts whose links are resolved (redirects followed) before cleaning.
    static let shortLinkHosts: Set<String> = [
        // Amazon
        //   Amazon blocks plain HTTP clients (#11); kept because it fails safe to the unresolved link.
        "amzn.to", "amzn.asia", "a.co",
        // YouTube
        "youtu.be",
        // Twitter / X
        "t.co",
        // Facebook
        "fb.watch",
        // Spotify
        "spoti.fi",
        // TikTok
        "vm.tiktok.com", "vt.tiktok.com",
    ]

    /// Redirect links that carry the real link in a query param; unwrapped offline.
    static let redirectWrappers: [RedirectWrapper] = [
        // Google redirects (Gmail, Docs, Search)
        //   Gmail and Google Docs wrap every link as google.com/url?q=<link>; search results use ?url=.
        RedirectWrapper(sites: ["google.*"], paths: ["/url"], params: ["q", "url"]),
        // Outlook Safe Links
        //   Regional hosts like nam12.safelinks.protection.outlook.com, sometimes with an /ap/... path.
        RedirectWrapper(sites: ["safelinks.protection.outlook.com"], paths: ["/*"], params: ["url"]),
        // Facebook and Messenger link redirects
        RedirectWrapper(sites: ["l.facebook.com", "lm.facebook.com", "l.messenger.com"], paths: ["/l.php"], params: ["u"]),
        // Instagram link redirects
        RedirectWrapper(sites: ["l.instagram.com"], paths: ["/"], params: ["u"]),
        // Threads link redirects
        RedirectWrapper(sites: ["l.threads.net", "l.threads.com"], paths: ["/"], params: ["u"]),
        // YouTube description and comment links
        RedirectWrapper(sites: ["youtube.com"], paths: ["/redirect"], params: ["q"]),
        // LinkedIn link redirects
        RedirectWrapper(sites: ["linkedin.com"], paths: ["/redir/redirect", "/safety/go"], params: ["url"]),
        // Reddit outbound links
        //   Path is the post ID, e.g. /t3_abc123.
        RedirectWrapper(sites: ["out.reddit.com"], paths: ["/*"], params: ["url"]),
        // DuckDuckGo result redirects
        RedirectWrapper(sites: ["duckduckgo.com"], paths: ["/l/"], params: ["uddg"]),
        // Slack link redirects
        RedirectWrapper(sites: ["slack-redir.net"], paths: ["/link"], params: ["url"]),
        // Steam link filter
        RedirectWrapper(sites: ["steamcommunity.com"], paths: ["/linkfilter/"], params: ["u", "url"]),
        // VK outbound links
        RedirectWrapper(sites: ["vk.com"], paths: ["/away.php"], params: ["to"]),
        // Tumblr link redirects
        RedirectWrapper(sites: ["t.umblr.com"], paths: ["/redirect"], params: ["z"]),
    ]

    /// Redirect links that carry the real link in their path; unwrapped offline.
    static let pathWrappers: [PathWrapper] = [
        // Google AMP viewer
        //   google.com/amp/s/<host>/<path> shows another site's AMP page; the original is https://<host>/<path>.
        PathWrapper(sites: ["google.*"], prefix: "/amp/s/", scheme: "https"),
    ]
}

/// A redirect on `sites` at `paths` (a trailing "*" matches any rest) whose first valid `params` value is the real link.
struct RedirectWrapper: Sendable {
    let sites: [String]
    let paths: [String]
    let params: [String]
}

/// A redirect on `sites` whose path after `prefix` is the real link, without its `scheme`.
struct PathWrapper: Sendable {
    let sites: [String]
    let prefix: String
    let scheme: String
}
