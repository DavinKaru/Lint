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
        //   feature marks a video reached via a youtu.be short link; si is the per-share token identifying who shared it.
        "youtube.com" to setOf("feature", "si"),
        "youtu.be" to setOf("feature", "si"),
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
    )
}
