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
        // AT Internet / Piano Analytics
        //   Campaign tag on many European news sites. Distinctive enough to strip everywhere.
        "xtor",
        // Beehiiv
        //   Per-subscriber click ID on links in Beehiiv newsletters, which are often on custom domains, so it's stripped everywhere.
        "_bhlid",
    ]

    /// Params only stripped on specific sites, because their names are generic enough to mean
    /// something real elsewhere. Keys match the host and its subdomains; a key ending in ".*"
    /// matches that name on any country domain (see `UrlCleaner.hostMatches`).
    static let siteParams: [String: Set<String>] = [
        // YouTube
        //   feature marks a video reached via a youtu.be short link; si is the per-share token identifying who shared it. pp encodes the search that led to the video.
        "youtube.com": ["feature", "si", "pp"],
        "youtu.be": ["feature", "si", "pp"],
        // Spotify
        //   si is the per-share token identifying who shared it.
        "spotify.com": ["si"],
        // Meta / Facebook (including Marketplace)
        //   eid is a Facebook tracking param, but Google Calendar uses ?eid= to identify an event (#2), so it's only stripped on Facebook. referral_code, referral_story_type and tracking are added to shared Marketplace listings.
        "facebook.com": ["eid", "referral_code", "referral_story_type", "tracking"],
        // Eventbrite
        //   aff records how a link was shared (e.g. ebdsshandroid, ebdsshsms); sg is a long per-share token. Eventbrite uses a domain per country, hence the wildcard.
        "eventbrite.*": ["aff", "sg"],
        // Fever
        //   suid looks like a per-user/session ID on shared event links.
        "feverup.com": ["suid"],
        // TikTok
        //   Appended once a vm.tiktok.com/vt.tiktok.com share link resolves, identifying the sharer's device/session and how the link was copied.
        "tiktok.com": ["is_from_webapp", "sender_device", "web_id", "share_app_id", "share_link_id", "share_item_id", "u_code", "_r", "_t"],
        // X / Twitter
        //   s says which share option was used (e.g. s=20, s=46); t is a per-share token identifying who shared it.
        "x.com": ["s", "t"],
        "twitter.com": ["s", "t"],
        // Google Maps
        //   Added to links resolved from maps.app.goo.gl: g_st is the share type and g_ep encodes the share context. entry= is left alone.
        "google.*": ["g_st", "g_ep"],
        // Amazon (full links, every country domain)
        //   Search and recommendation context on product links (keywords and sprefix carry what you searched for). Variant selectors th and psc are kept, and so is the tag affiliate ID (see the affiliate-ID decision issue).
        "amazon.*": ["crid", "dib", "dib_tag", "keywords", "sprefix", "sr", "pd_rd_w", "pd_rd_r", "pd_rd_wg", "pd_rd_i", "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m", "content-id", "linkCode", "linkId", "creativeASIN", "social_share", "_encoding", "ref_"],
        // Apple Music, Podcasts and App Store
        //   uo and ct are campaign/origin tracking. i= (the track or episode), mt= and app= are kept; the at= affiliate token is kept too.
        "music.apple.com": ["uo", "ct"],
        "podcasts.apple.com": ["uo", "ct"],
        "apps.apple.com": ["uo", "ct"],
        "itunes.apple.com": ["uo", "ct"],
        // Substack
        //   r is the sharer's referral ID. triedRedirect is left alone because custom-domain redirects use it.
        "substack.com": ["r", "showWelcomeOnShare"],
        // Pinterest
        //   Added to pins opened from pin.it share links: invite_code and sender identify who shared it.
        "pinterest.*": ["invite_code", "sender", "sfo", "mweb_unauth_id"],
        // LinkedIn
        //   rcm identifies the member who shared a post; lipi, midToken, midSig and trkEmail are page and email tracking. otpToken (email sign-in) is deliberately not listed.
        "linkedin.com": ["rcm", "lipi", "midToken", "midSig", "trkEmail"],
        // Threads
        //   Per-share tracking tokens on post links.
        "threads.net": ["xmt", "slof"],
        "threads.com": ["xmt", "slof"],
        // Tumblr
        //   source=share marks how a post was shared.
        "tumblr.com": ["source"],
        // Quora
        //   Share-sheet tracking on answer links.
        "quora.com": ["ch", "oid", "share", "srid", "target_type"],
        // SoundCloud
        //   si is the per-share token, as on Spotify and YouTube.
        "soundcloud.com": ["si"],
        // Twitch
        //   Share tracking on clip and channel links.
        "twitch.tv": ["tt_medium", "tt_content", "tt_campaign"],
        // Vimeo
        //   share=copy marks how the link was copied. Private-video hashes (in the path or h=) are kept.
        "vimeo.com": ["share"],
        // Netflix
        //   Share source and tracking IDs on title links. clip= is kept.
        "netflix.com": ["s", "trkid", "trg"],
        // Tidal
        //   The bare ?u Tidal's share sheet appends.
        "tidal.com": ["u"],
        // Shazam
        //   referrer=share on song links.
        "shazam.com": ["referrer"],
        // Google Docs and Drive
        //   usp=sharing / drive_link / share_link only records which button made the link. resourcekey and everything else is kept.
        "docs.google.com": ["usp"],
        "drive.google.com": ["usp"],
        // Notion
        //   pvs is the page-view source.
        "notion.so": ["pvs"],
        "notion.site": ["pvs"],
        // Figma
        //   t is a per-share tracking token. node-id and everything else is kept.
        "figma.com": ["t"],
        // Canva
        //   utlId is a per-share link ID (alongside utm_*). The view token in the path is kept.
        "canva.com": ["utlId"],
        // eBay
        //   Search, share-sheet (sss*) and partner-network (mk*, campid) tracking. var= picks the variation and epid= the product, so both are kept.
        "ebay.*": ["_trkparms", "_trksid", "_from", "hash", "mkcid", "mkevt", "mkrid", "campid", "toolid", "customid", "ssspo", "sssrc", "ssuid", "widget_ver", "amdata"],
        // AliExpress
        //   Page, algorithm and share tracking. pdp_ext_f and pdp_npi are kept: they can carry the chosen SKU and price.
        "aliexpress.*": ["spm", "scm", "scm_id", "scm-url", "pvid", "algo_pvid", "algo_exp_id", "aff_platform", "aff_trace_key", "aff_fcid", "aff_fsk", "sk", "terminal_id", "afSmartRedirect", "gatewayAdapt", "sourceType", "srcSns", "businessType", "social_params", "tt", "utparam", "gps-id", "curPageLogUid", "bizType", "mp", "_randl_shipto"],
        // Etsy
        //   Search and share tracking on listing links. variation0/variation1 pick the options and are kept.
        "etsy.com": ["click_key", "click_sum", "ga_order", "ga_search_type", "ga_view_type", "ga_search_query", "organic_search_click", "plkey", "sts", "frs", "pro", "sr_prefetch", "pf_from", "logging_key", "content_source", "share_time"],
        // Shein
        //   Share and page-source tracking. mallCode picks the warehouse and is kept.
        "shein.*": ["src_identifier", "src_module", "src_tab_page_id", "scici", "ici", "share_from", "url_from", "onelink"],
        // Temu
        //   Session, sharer (share_uin) and ad tracking. goods_id, sku_id and _x_ns_sku_id pick the product and are kept.
        "temu.com": ["refer_page_name", "refer_page_id", "refer_page_sn", "_x_sessn_id", "share_uin", "_x_vst_scene", "_x_ads_channel", "_x_ads_sub_channel", "_x_ads_account", "_x_ads_set", "_x_ads_id", "_x_ads_creative_id"],
        // Walmart
        //   ath* are recommendation-carousel tracking. classType and selected are kept.
        "walmart.com": ["athbdg", "athcpid", "athpgid", "athznid", "athieid", "athstid", "athguid", "athwpid", "athena", "athancid", "sourceid", "veh", "wmlspartner"],
        // Vinted
        //   Where the item was opened from. referrer is generic, so it's only stripped here.
        "vinted.*": ["referrer", "homepage_session_id"],
        // BBC
        //   AT Internet tags on shared articles. A blanket at_* prefix would be too broad for other sites.
        "bbc.co.uk": ["at_medium", "at_campaign", "at_campaign_type", "at_link_id", "at_link_origin", "at_link_type", "at_format", "at_ptr_name", "at_ptr_type", "at_bbc_team", "at_custom1", "at_custom2", "at_custom3", "at_custom4"],
        "bbc.com": ["at_medium", "at_campaign", "at_campaign_type", "at_link_id", "at_link_origin", "at_link_type", "at_format", "at_ptr_name", "at_ptr_type", "at_bbc_team", "at_custom1", "at_custom2", "at_custom3", "at_custom4"],
        // The Guardian
        //   CMP=share_btn_link and friends record which share button was used.
        "theguardian.com": ["CMP", "INTCMP"],
        // Meetup
        //   Recommendation and search tracking on event links.
        "meetup.com": ["recId", "recSource", "searchId", "eventOrigin", "_xtd"],
        // Klook
        //   Page tracking. aid (affiliate) is kept for now, see the affiliate-ID decision.
        "klook.com": ["spm", "clickId"],
        // Yelp
        //   uid identifies the Yelp member who shared the link.
        "yelp.*": ["uid"],
        // Deezer
        //   App deep-link plumbing added to shared track links.
        "deezer.com": ["deferredFl", "host"],
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
        // Google Maps
        //   Google Maps share links.
        "maps.app.goo.gl",
        // Reddit
        "redd.it",
        // Pinterest
        "pin.it",
        // LinkedIn
        "lnkd.in",
        // Facebook
        "fb.me",
        // SoundCloud
        "on.soundcloud.com",
        // eBay
        "ebay.us",
        // AliExpress
        "a.aliexpress.com",
        // Flipboard
        "flip.it",
        // Deezer
        "link.deezer.com",
    ]

    /// Short links that live on a path of a normal site; each "*" matches one path segment.
    static let shortLinkPaths: [ShortLinkPath] = [
        // Reddit
        //   App share links like reddit.com/r/<sub>/s/<code>; the full post link carries share_id and utm_*.
        ShortLinkPath(sites: ["reddit.com"], paths: ["/r/*/s/*"]),
        // Facebook
        //   Share links like facebook.com/share/p/<code>/ and /share/r/<code>/.
        ShortLinkPath(sites: ["facebook.com"], paths: ["/share/*", "/share/*/*"]),
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

/// Short links on `sites` whose path matches one of `paths` ("*" = one segment).
struct ShortLinkPath: Sendable {
    let sites: [String]
    let paths: [String]
}

/// A redirect on `sites` whose path after `prefix` is the real link, without its `scheme`.
struct PathWrapper: Sendable {
    let sites: [String]
    let prefix: String
    let scheme: String
}
