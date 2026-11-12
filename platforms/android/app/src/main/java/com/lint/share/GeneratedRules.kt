// Generated from shared/rules/rules.json by shared/rules/generate.py. Don't edit by hand.

package com.lint.share

internal object GeneratedRules {

    /** Params starting with any of these are stripped on every site. */
    val TRACKING_PREFIXES: List<String> = listOf(
        // Google Analytics campaign tags (used everywhere)
        "utm_",
        // Matomo campaign tags
        "mtm_",
        // Secret Media Network (Secret Melbourne, Secret London, ...)
        //   Campaign tags it adds to partner links, e.g. Fever tickets (cp_smn_source, cp_smn_content, cp_smn_term). Distinctive enough to strip on every site, like utm_.
        "cp_smn_",
    )

    /** Params stripped on every site. */
    val TRACKING_PARAMS: Set<String> = setOf(
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
    )

    /**
     * Params only stripped on specific sites, because their names are generic enough to mean
     * something real elsewhere. Keys match the host and its subdomains; a key ending in ".*"
     * matches that name on any country domain (see UrlCleaner.hostMatches).
     */
    val SITE_PARAMS: Map<String, Set<String>> = mapOf(
        // YouTube
        //   feature marks a video reached via a youtu.be short link; si is the per-share token identifying who shared it. pp encodes the search that led to the video.
        "youtube.com" to setOf("feature", "si", "pp"),
        "youtu.be" to setOf("feature", "si", "pp"),
        // Spotify
        //   si is the per-share token identifying who shared it.
        "spotify.com" to setOf("si"),
        // Meta / Facebook
        //   eid is a Facebook tracking param, but Google Calendar uses ?eid= to identify an event (#2), so it's only stripped on Facebook.
        "facebook.com" to setOf("eid"),
        // Eventbrite
        //   aff records how a link was shared (e.g. ebdsshandroid, ebdsshsms); sg is a long per-share token. Eventbrite uses a domain per country, hence the wildcard.
        "eventbrite.*" to setOf("aff", "sg"),
        // Fever
        //   suid looks like a per-user/session ID on shared event links.
        "feverup.com" to setOf("suid"),
        // TikTok
        //   Appended once a vm.tiktok.com/vt.tiktok.com share link resolves, identifying the sharer's device/session and how the link was copied.
        "tiktok.com" to setOf("is_from_webapp", "sender_device", "web_id", "share_app_id", "share_link_id", "share_item_id", "u_code", "_r", "_t"),
        // X / Twitter
        //   s says which share option was used (e.g. s=20, s=46); t is a per-share token identifying who shared it.
        "x.com" to setOf("s", "t"),
        "twitter.com" to setOf("s", "t"),
        // Google Maps
        //   Added to links resolved from maps.app.goo.gl: g_st is the share type and g_ep encodes the share context. entry= is left alone.
        "google.*" to setOf("g_st", "g_ep"),
        // Amazon (full links, every country domain)
        //   Search and recommendation context on product links (keywords and sprefix carry what you searched for). Variant selectors th and psc are kept, and so is the tag affiliate ID (see the affiliate-ID decision issue).
        "amazon.*" to setOf("crid", "dib", "dib_tag", "keywords", "sprefix", "sr", "pd_rd_w", "pd_rd_r", "pd_rd_wg", "pd_rd_i", "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m", "content-id", "linkCode", "linkId", "creativeASIN", "social_share", "_encoding", "ref_"),
        // Apple Music, Podcasts and App Store
        //   uo and ct are campaign/origin tracking. i= (the track or episode), mt= and app= are kept; the at= affiliate token is kept too.
        "music.apple.com" to setOf("uo", "ct"),
        "podcasts.apple.com" to setOf("uo", "ct"),
        "apps.apple.com" to setOf("uo", "ct"),
        "itunes.apple.com" to setOf("uo", "ct"),
        // Substack
        //   r is the sharer's referral ID. triedRedirect is left alone because custom-domain redirects use it.
        "substack.com" to setOf("r", "showWelcomeOnShare"),
    )

    /** Hosts whose links are resolved (redirects followed) before cleaning. */
    val SHORT_LINK_HOSTS: Set<String> = setOf(
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
        // Google Maps
        //   Google Maps share links.
        "maps.app.goo.gl",
        // Reddit
        "redd.it",
    )

    /** Short links that live on a path of a normal site; each "*" matches one path segment. */
    val SHORT_LINK_PATHS: List<ShortLinkPath> = listOf(
        // Reddit
        //   App share links like reddit.com/r/<sub>/s/<code>; the full post link carries share_id and utm_*.
        ShortLinkPath(listOf("reddit.com"), listOf("/r/*/s/*")),
        // Facebook
        //   Share links like facebook.com/share/p/<code>/ and /share/r/<code>/.
        ShortLinkPath(listOf("facebook.com"), listOf("/share/*", "/share/*/*")),
    )

    /** Redirect links that carry the real link in a query param; unwrapped offline. */
    val REDIRECT_WRAPPERS: List<RedirectWrapper> = listOf(
        // Google redirects (Gmail, Docs, Search)
        //   Gmail and Google Docs wrap every link as google.com/url?q=<link>; search results use ?url=.
        RedirectWrapper(listOf("google.*"), listOf("/url"), listOf("q", "url")),
        // Outlook Safe Links
        //   Regional hosts like nam12.safelinks.protection.outlook.com, sometimes with an /ap/... path.
        RedirectWrapper(listOf("safelinks.protection.outlook.com"), listOf("/*"), listOf("url")),
        // Facebook and Messenger link redirects
        RedirectWrapper(listOf("l.facebook.com", "lm.facebook.com", "l.messenger.com"), listOf("/l.php"), listOf("u")),
        // Instagram link redirects
        RedirectWrapper(listOf("l.instagram.com"), listOf("/"), listOf("u")),
        // Threads link redirects
        RedirectWrapper(listOf("l.threads.net", "l.threads.com"), listOf("/"), listOf("u")),
        // YouTube description and comment links
        RedirectWrapper(listOf("youtube.com"), listOf("/redirect"), listOf("q")),
        // LinkedIn link redirects
        RedirectWrapper(listOf("linkedin.com"), listOf("/redir/redirect", "/safety/go"), listOf("url")),
        // Reddit outbound links
        //   Path is the post ID, e.g. /t3_abc123.
        RedirectWrapper(listOf("out.reddit.com"), listOf("/*"), listOf("url")),
        // DuckDuckGo result redirects
        RedirectWrapper(listOf("duckduckgo.com"), listOf("/l/"), listOf("uddg")),
        // Slack link redirects
        RedirectWrapper(listOf("slack-redir.net"), listOf("/link"), listOf("url")),
        // Steam link filter
        RedirectWrapper(listOf("steamcommunity.com"), listOf("/linkfilter/"), listOf("u", "url")),
        // VK outbound links
        RedirectWrapper(listOf("vk.com"), listOf("/away.php"), listOf("to")),
        // Tumblr link redirects
        RedirectWrapper(listOf("t.umblr.com"), listOf("/redirect"), listOf("z")),
    )

    /** Redirect links that carry the real link in their path; unwrapped offline. */
    val PATH_WRAPPERS: List<PathWrapper> = listOf(
        // Google AMP viewer
        //   google.com/amp/s/<host>/<path> shows another site's AMP page; the original is https://<host>/<path>.
        PathWrapper(listOf("google.*"), "/amp/s/", "https"),
    )
}

/** A redirect on [sites] at [paths] (a trailing "*" matches any rest) whose first valid [params] value is the real link. */
internal data class RedirectWrapper(val sites: List<String>, val paths: List<String>, val params: List<String>)

/** A redirect on [sites] whose path after [prefix] is the real link, without its [scheme]. */
internal data class PathWrapper(val sites: List<String>, val prefix: String, val scheme: String)

/** Short links on [sites] whose path matches one of [paths] ("*" = one segment). */
internal data class ShortLinkPath(val sites: List<String>, val paths: List<String>)
