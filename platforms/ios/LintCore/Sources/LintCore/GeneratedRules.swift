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
        //   ref_src is distinctive enough to strip everywhere. ref itself is only stripped on sites that use it for tracking: GitHub and GitLab links use ?ref= for the branch (#15).
        "ref_src",
        // Pinterest
        "epik",
        // Google (Ads, Analytics, Search, Shopping)
        "aqs", "iflsig", "pcampaignid", "rlz", "srsltid", "sxsrf", "uact", "ved", "_ga", "_gl",
        // Meta / Facebook
        //   eid is Facebook-only, see siteParams.
        "comment_tracking", "eav", "mibextid", "__tn__",
        // Snapchat
        "ScCid",
        // Reddit
        "correlation_id", "rdt", "ref_campaign", "ref_source",
        // Amazon
        "dchild", "refRID", "spIA",
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
        "facebook.com": ["eid", "referral_code", "referral_story_type", "tracking", "ref"],
        // Eventbrite
        //   aff records how a link was shared (e.g. ebdsshandroid, ebdsshsms) and sg is a long per-share token, both added when you share. Eventbrite uses a domain per country, hence the wildcard.
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
        // Google (Maps, Search)
        //   Maps links resolved from maps.app.goo.gl carry g_st (the share type) and g_ep (the share context); entry= is left alone. cd and ei are search-result tracking, only stripped on Google because the names are generic (#15).
        "google.*": ["g_st", "g_ep", "cd", "ei"],
        // Amazon (full links, every country domain)
        //   Search and recommendation context on product links (sprefix carries what you searched for). Variant selectors th and psc are kept. Affiliate link params (tag, linkCode, linkId, ascsubtag, creativeASIN, camp, creative) are kept, see affiliateParams. keywords is only stripped on product pages (below): older search links (amazon.com/s?keywords=...) use it as the query.
        "amazon.*": ["crid", "dib", "dib_tag", "sprefix", "sr", "pd_rd_w", "pd_rd_r", "pd_rd_wg", "pd_rd_i", "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m", "content-id", "social_share", "_encoding", "ref_", "qid", "ref"],
        // Apple Music, Podcasts and App Store
        //   uo is origin tracking. i= (the track or episode), mt= and app= are kept, and so are the at= affiliate token and ct= campaign token (see affiliateParams).
        "music.apple.com": ["uo"],
        "podcasts.apple.com": ["uo"],
        "apps.apple.com": ["uo"],
        "itunes.apple.com": ["uo"],
        // Substack
        //   r is the referral ID of whoever shared the link, added when you share, so it identifies you and is removed (unlike affiliate IDs, see affiliateParams). triedRedirect is left alone because custom-domain redirects use it.
        "substack.com": ["r", "showWelcomeOnShare"],
        // Pinterest
        //   Added to pins opened from pin.it share links. invite_code and sender are only stripped on pin pages (below): Pinterest also uses them for group-board and sign-up invites.
        "pinterest.*": ["sfo", "mweb_unauth_id"],
        // LinkedIn
        //   rcm identifies the member who shared a post; lipi, midToken, midSig and trkEmail are page and email tracking. otpToken (email sign-in) is deliberately not listed.
        "linkedin.com": ["rcm", "lipi", "midToken", "midSig", "trkEmail", "refId", "trackingId", "trk"],
        // Threads
        //   Per-share tracking tokens on post links.
        "threads.net": ["xmt", "slof"],
        "threads.com": ["xmt", "slof"],
        // Quora
        //   Share-sheet tracking on answer links. share and srid are kept: they let a logged-out recipient past the sign-in wall.
        "quora.com": ["ch", "oid", "target_type"],
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
        //   Search and share-sheet (sss*) tracking. var= picks the variation and epid= the product, so both are kept, and so are the eBay Partner Network params (see affiliateParams). eBay's own app shares carry mkcid, mkrid and mkevt too; they're kept as well, since they can't be told apart from a partner's.
        "ebay.*": ["_trkparms", "_trksid", "_from", "hash", "ssspo", "sssrc", "ssuid", "widget_ver"],
        // AliExpress
        //   Page, algorithm and share tracking. pdp_ext_f and pdp_npi are kept: they can carry the chosen SKU and price. The aff_* and sk affiliate params are kept (see affiliateParams).
        "aliexpress.*": ["spm", "scm", "scm_id", "scm-url", "pvid", "algo_pvid", "algo_exp_id", "terminal_id", "afSmartRedirect", "gatewayAdapt", "sourceType", "srcSns", "businessType", "social_params", "tt", "utparam", "gps-id", "curPageLogUid", "bizType", "mp", "_randl_shipto"],
        // Etsy
        //   Search and share tracking on listing links. variation0/variation1 pick the options and are kept.
        "etsy.com": ["click_key", "click_sum", "ga_order", "ga_search_type", "ga_view_type", "ga_search_query", "organic_search_click", "plkey", "sts", "frs", "pro", "sr_prefetch", "pf_from", "logging_key", "content_source", "share_time", "ref"],
        // Shein
        //   Share and page-source tracking. mallCode picks the warehouse and is kept.
        "shein.*": ["src_identifier", "src_module", "src_tab_page_id", "scici", "ici", "share_from", "url_from", "onelink"],
        // Temu
        //   Session and sharer (share_uin) tracking. goods_id, sku_id and _x_ns_sku_id pick the product and are kept, and so are the _x_ads_* params, which credit Temu affiliates (see affiliateParams).
        "temu.com": ["refer_page_name", "refer_page_id", "refer_page_sn", "_x_sessn_id", "share_uin", "_x_vst_scene"],
        // Walmart
        //   ath* are recommendation-carousel tracking. classType and selected are kept, and so are the affiliate params (see affiliateParams).
        "walmart.com": ["athbdg", "athcpid", "athpgid", "athznid", "athieid", "athstid", "athguid", "athwpid", "athena", "athancid"],
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
        //   Page tracking. aid (affiliate) is kept, see affiliateParams.
        "klook.com": ["spm", "clickId"],
        // Yelp
        //   uid identifies the Yelp member who shared the link.
        "yelp.*": ["uid"],
        // Deezer
        //   App deep-link plumbing added to shared track links.
        "deezer.com": ["deferredFl", "host"],
        // Reddit
        //   share_id and ref on post links; share_id is only stripped here because the name is generic (#15).
        "reddit.com": ["share_id", "ref"],
        // New York Times
        //   smid marks how an article was shared (smid=nytcore-ios-share). Not stripped on Amazon, where smid picks the seller's offer (#15).
        "nytimes.com": ["smid"],
        // Kickstarter
        //   ref marks where a project link came from.
        "kickstarter.com": ["ref"],
        // Goodreads
        //   ref marks which part of the page a book link came from.
        "goodreads.com": ["ref"],
        // Seek (AU)
        //   ref marks where a job link was opened from (ref=search-standalone).
        "seek.com.au": ["ref"],
        // Snapchat
        //   share_id identifies the share on profile links.
        "snapchat.com": ["share_id"],
    ]

    /// Params only stripped on some pages of a site (see `UrlCleaner.pathMatches`).
    static let sitePathParams: [SitePathParams] = [
        // Amazon product pages
        //   keywords on a product link is what you searched for to find it, and srs the store page it was opened from. Only stripped on product pages: on search links (/s?keywords=...) keywords is the query, and srs can pick the store being browsed (#15). /-/<lang>/ paths are the same pages in another language.
        SitePathParams(sites: ["amazon.*"], paths: ["/dp/*/**", "/*/dp/*/**", "/gp/product/*/**", "/gp/aw/d/*/**", "/-/*/dp/*/**", "/-/*/*/dp/*/**", "/-/*/gp/product/*/**", "/-/*/gp/aw/d/*/**"], params: ["keywords", "srs"]),
        // Pinterest pin pages
        //   Who shared the pin. Only stripped on /pin/<id>/ pages: on group-board and sign-up links they are the invite.
        SitePathParams(sites: ["pinterest.*"], paths: ["/pin/*/**"], params: ["invite_code", "sender"]),
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

    /// Short links that live on a path of a normal site (see `UrlCleaner.pathMatches`).
    static let shortLinkPaths: [ShortLinkPath] = [
        // Reddit
        //   App share links like reddit.com/r/<sub>/s/<code>; the full post link carries share_id and utm_*.
        ShortLinkPath(sites: ["reddit.com"], paths: ["/r/*/s/*"]),
        // Facebook
        //   Share links like facebook.com/share/p/<code>/ and /share/r/<code>/.
        ShortLinkPath(sites: ["facebook.com"], paths: ["/share/*", "/share/*/*"]),
        // Mailchimp
        //   Newsletter click links on <account>.<dc>.list-manage.com. The e= param identifies the subscriber, so resolving replaces it with the destination. Resolving counts as a click by the person sharing. identifiesYou: if it redirects straight to a sign-in page, that page is shared rather than this link.
        ShortLinkPath(sites: ["list-manage.com"], paths: ["/track/click"], identifiesYou: true),
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
        // Bing search results
        //   Bing's result links carry the real link in u= as "a1" followed by unpadded base64url.
        RedirectWrapper(sites: ["bing.com"], paths: ["/ck/a"], params: ["u"], base64Prefix: "a1"),
        // Google cookie consent
        //   Resolving a maps.app.goo.gl or youtu.be link from a cookie-less device (e.g. in the EU) can land here; continue= is the real link. Google only continues to its own sites, so other targets are left alone.
        RedirectWrapper(sites: ["consent.google.com", "consent.youtube.com"], paths: ["/ml", "/m"], params: ["continue"], targetSites: ["google.*", "youtube.com"]),
        // Facebook sign-in
        //   Resolving a Facebook short link without being signed in can land here; next= is the real link. Facebook only continues to its own pages, so other targets are left alone.
        RedirectWrapper(sites: ["facebook.com"], paths: ["/login/", "/login.php"], params: ["next"], targetSites: ["facebook.com"]),
        // AliExpress share page
        //   Where a.aliexpress.com share links land: a share page whose redirectUrl= is the product link.
        RedirectWrapper(sites: ["star.aliexpress.com"], paths: ["/share/share.htm"], params: ["redirectUrl"], targetSites: ["aliexpress.*"]),
    ]

    /// Redirect links that carry the real link in their path; unwrapped offline.
    static let pathWrappers: [PathWrapper] = [
        // Google AMP viewer
        //   google.com/amp/s/<host>/<path> shows another site's AMP page; the original is https://<host>/<path>.
        PathWrapper(sites: ["google.*"], prefix: "/amp/s/", scheme: "https"),
    ]

    /// Sign-in and consent pages: a short link that redirects to one stops at the hop before.
    static let deadEndPages: [SitePaths] = [
        // Google and YouTube cookie consent
        SitePaths(sites: ["consent.google.com", "consent.youtube.com"], paths: ["/**"]),
        // Google sign-in
        //   Only the interactive sign-in pages: other accounts.google.com pages (CheckCookie, ...) can pass a browser straight on to the content.
        SitePaths(sites: ["accounts.google.com"], paths: ["/ServiceLogin/**", "/signin/**", "/v3/signin/**", "/AccountChooser/**", "/InteractiveLogin/**"]),
        // Facebook sign-in
        SitePaths(sites: ["facebook.com"], paths: ["/login/**", "/login.php"]),
        // Instagram sign-in
        SitePaths(sites: ["instagram.com"], paths: ["/accounts/login/**"]),
        // LinkedIn sign-in wall
        SitePaths(sites: ["linkedin.com"], paths: ["/authwall/**", "/login/**", "/uas/login/**"]),
        // X / Twitter sign-in
        SitePaths(sites: ["x.com", "twitter.com"], paths: ["/login/**", "/i/flow/login/**"]),
        // Reddit sign-in
        SitePaths(sites: ["reddit.com"], paths: ["/login/**", "/account/login/**"]),
        // TikTok sign-in
        SitePaths(sites: ["tiktok.com"], paths: ["/login/**"]),
        // Amazon sign-in
        SitePaths(sites: ["amazon.*"], paths: ["/ap/signin/**"]),
    ]
}

/// A redirect on `sites` at `paths` (a trailing "*" matches any rest) whose first valid `params` value is the real
/// link: percent-encoded, or if `base64Prefix` is set, that prefix followed by the link in unpadded base64url.
/// If `targetSites` is set, the real link must be on one of them, or the wrapper is left alone.
struct RedirectWrapper: Sendable {
    let sites: [String]
    let paths: [String]
    let params: [String]
    var base64Prefix: String? = nil
    var targetSites: [String]? = nil
}

/// Short links on `sites` whose path matches one of `paths` (see `UrlCleaner.pathMatches`). If `identifiesYou`,
/// the link itself identifies the person sharing it, so it's never kept in place of a sign-in page.
struct ShortLinkPath: Sendable {
    let sites: [String]
    let paths: [String]
    var identifiesYou = false
}

/// `params` stripped on `sites`, but only where the path matches one of `paths` (see `UrlCleaner.pathMatches`).
struct SitePathParams: Sendable {
    let sites: [String]
    let paths: [String]
    let params: Set<String>
}

/// Pages on `sites` whose path matches one of `paths` (see `UrlCleaner.pathMatches`).
struct SitePaths: Sendable {
    let sites: [String]
    let paths: [String]
}

/// A redirect on `sites` whose path after `prefix` is the real link, without its `scheme`.
struct PathWrapper: Sendable {
    let sites: [String]
    let prefix: String
    let scheme: String
}
