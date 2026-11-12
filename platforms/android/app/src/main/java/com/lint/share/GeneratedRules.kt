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
        // Meta / Facebook (including Marketplace)
        //   eid is a Facebook tracking param, but Google Calendar uses ?eid= to identify an event (#2), so it's only stripped on Facebook. referral_code, referral_story_type and tracking are added to shared Marketplace listings.
        "facebook.com" to setOf("eid", "referral_code", "referral_story_type", "tracking", "ref"),
        // Eventbrite
        //   aff records how a link was shared (e.g. ebdsshandroid, ebdsshsms) and sg is a long per-share token, both added when you share. Eventbrite uses a domain per country, hence the wildcard.
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
        // Google (Maps, Search)
        //   Maps links resolved from maps.app.goo.gl carry g_st (the share type) and g_ep (the share context); entry= is left alone. cd and ei are search-result tracking, only stripped on Google because the names are generic (#15).
        "google.*" to setOf("g_st", "g_ep", "cd", "ei"),
        // Amazon (full links, every country domain)
        //   Search and recommendation context on product links (sprefix carries what you searched for). Variant selectors th and psc are kept. Affiliate link params (tag, linkCode, linkId, ascsubtag, creativeASIN, camp, creative) are kept, see affiliateParams. keywords is only stripped on product pages (below): older search links (amazon.com/s?keywords=...) use it as the query.
        "amazon.*" to setOf("crid", "dib", "dib_tag", "sprefix", "sr", "pd_rd_w", "pd_rd_r", "pd_rd_wg", "pd_rd_i", "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m", "content-id", "social_share", "_encoding", "ref_", "qid", "ref"),
        // Apple Music, Podcasts and App Store
        //   uo is origin tracking. i= (the track or episode), mt= and app= are kept, and so are the at= affiliate token and ct= campaign token (see affiliateParams).
        "music.apple.com" to setOf("uo"),
        "podcasts.apple.com" to setOf("uo"),
        "apps.apple.com" to setOf("uo"),
        "itunes.apple.com" to setOf("uo"),
        // Substack
        //   r is the referral ID of whoever shared the link, added when you share, so it identifies you and is removed (unlike affiliate IDs, see affiliateParams). triedRedirect is left alone because custom-domain redirects use it.
        "substack.com" to setOf("r", "showWelcomeOnShare"),
        // Pinterest
        //   Added to pins opened from pin.it share links. invite_code and sender are only stripped on pin pages (below): Pinterest also uses them for group-board and sign-up invites.
        "pinterest.*" to setOf("sfo", "mweb_unauth_id"),
        // LinkedIn
        //   rcm identifies the member who shared a post; lipi, midToken, midSig and trkEmail are page and email tracking. otpToken (email sign-in) is deliberately not listed.
        "linkedin.com" to setOf("rcm", "lipi", "midToken", "midSig", "trkEmail", "refId", "trackingId", "trk"),
        // Threads
        //   Per-share tracking tokens on post links.
        "threads.net" to setOf("xmt", "slof"),
        "threads.com" to setOf("xmt", "slof"),
        // Quora
        //   Share-sheet tracking on answer links. share and srid are kept: they let a logged-out recipient past the sign-in wall.
        "quora.com" to setOf("ch", "oid", "target_type"),
        // SoundCloud
        //   si is the per-share token, as on Spotify and YouTube.
        "soundcloud.com" to setOf("si"),
        // Twitch
        //   Share tracking on clip and channel links.
        "twitch.tv" to setOf("tt_medium", "tt_content", "tt_campaign"),
        // Vimeo
        //   share=copy marks how the link was copied. Private-video hashes (in the path or h=) are kept.
        "vimeo.com" to setOf("share"),
        // Netflix
        //   Share source and tracking IDs on title links. clip= is kept.
        "netflix.com" to setOf("s", "trkid", "trg"),
        // Tidal
        //   The bare ?u Tidal's share sheet appends.
        "tidal.com" to setOf("u"),
        // Shazam
        //   referrer=share on song links.
        "shazam.com" to setOf("referrer"),
        // Google Docs and Drive
        //   usp=sharing / drive_link / share_link only records which button made the link. resourcekey and everything else is kept.
        "docs.google.com" to setOf("usp"),
        "drive.google.com" to setOf("usp"),
        // Notion
        //   pvs is the page-view source.
        "notion.so" to setOf("pvs"),
        "notion.site" to setOf("pvs"),
        // Figma
        //   t is a per-share tracking token. node-id and everything else is kept.
        "figma.com" to setOf("t"),
        // Canva
        //   utlId is a per-share link ID (alongside utm_*). The view token in the path is kept.
        "canva.com" to setOf("utlId"),
        // eBay
        //   Search and share-sheet (sss*) tracking. var= picks the variation and epid= the product, so both are kept, and so are the eBay Partner Network params (see affiliateParams). eBay's own app shares carry mkcid, mkrid and mkevt too; they're kept as well, since they can't be told apart from a partner's.
        "ebay.*" to setOf("_trkparms", "_trksid", "_from", "hash", "ssspo", "sssrc", "ssuid", "widget_ver"),
        // AliExpress
        //   Page, algorithm and share tracking. pdp_ext_f and pdp_npi are kept: they can carry the chosen SKU and price. The aff_* and sk affiliate params are kept (see affiliateParams).
        "aliexpress.*" to setOf("spm", "scm", "scm_id", "scm-url", "pvid", "algo_pvid", "algo_exp_id", "terminal_id", "afSmartRedirect", "gatewayAdapt", "sourceType", "srcSns", "businessType", "social_params", "tt", "utparam", "gps-id", "curPageLogUid", "bizType", "mp", "_randl_shipto"),
        // Etsy
        //   Search and share tracking on listing links. variation0/variation1 pick the options and are kept.
        "etsy.com" to setOf("click_key", "click_sum", "ga_order", "ga_search_type", "ga_view_type", "ga_search_query", "organic_search_click", "plkey", "sts", "frs", "pro", "sr_prefetch", "pf_from", "logging_key", "content_source", "share_time", "ref"),
        // Shein
        //   Share and page-source tracking. mallCode picks the warehouse and is kept.
        "shein.*" to setOf("src_identifier", "src_module", "src_tab_page_id", "scici", "ici", "share_from", "url_from", "onelink"),
        // Temu
        //   Session and sharer (share_uin) tracking. goods_id, sku_id and _x_ns_sku_id pick the product and are kept, and so are the _x_ads_* params, which credit Temu affiliates (see affiliateParams).
        "temu.com" to setOf("refer_page_name", "refer_page_id", "refer_page_sn", "_x_sessn_id", "share_uin", "_x_vst_scene"),
        // Walmart
        //   ath* are recommendation-carousel tracking. classType and selected are kept, and so are the affiliate params (see affiliateParams).
        "walmart.com" to setOf("athbdg", "athcpid", "athpgid", "athznid", "athieid", "athstid", "athguid", "athwpid", "athena", "athancid"),
        // Vinted
        //   Where the item was opened from. referrer is generic, so it's only stripped here.
        "vinted.*" to setOf("referrer", "homepage_session_id"),
        // BBC
        //   AT Internet tags on shared articles. A blanket at_* prefix would be too broad for other sites.
        "bbc.co.uk" to setOf("at_medium", "at_campaign", "at_campaign_type", "at_link_id", "at_link_origin", "at_link_type", "at_format", "at_ptr_name", "at_ptr_type", "at_bbc_team", "at_custom1", "at_custom2", "at_custom3", "at_custom4"),
        "bbc.com" to setOf("at_medium", "at_campaign", "at_campaign_type", "at_link_id", "at_link_origin", "at_link_type", "at_format", "at_ptr_name", "at_ptr_type", "at_bbc_team", "at_custom1", "at_custom2", "at_custom3", "at_custom4"),
        // The Guardian
        //   CMP=share_btn_link and friends record which share button was used.
        "theguardian.com" to setOf("CMP", "INTCMP"),
        // Meetup
        //   Recommendation and search tracking on event links.
        "meetup.com" to setOf("recId", "recSource", "searchId", "eventOrigin", "_xtd"),
        // Klook
        //   Page tracking. aid (affiliate) is kept, see affiliateParams.
        "klook.com" to setOf("spm", "clickId"),
        // Yelp
        //   uid identifies the Yelp member who shared the link.
        "yelp.*" to setOf("uid"),
        // Deezer
        //   App deep-link plumbing added to shared track links.
        "deezer.com" to setOf("deferredFl", "host"),
        // Reddit
        //   share_id and ref on post links; share_id is only stripped here because the name is generic (#15).
        "reddit.com" to setOf("share_id", "ref"),
        // New York Times
        //   smid marks how an article was shared (smid=nytcore-ios-share). Not stripped on Amazon, where smid picks the seller's offer (#15).
        "nytimes.com" to setOf("smid"),
        // Kickstarter
        //   ref marks where a project link came from.
        "kickstarter.com" to setOf("ref"),
        // Goodreads
        //   ref marks which part of the page a book link came from.
        "goodreads.com" to setOf("ref"),
        // Seek (AU)
        //   ref marks where a job link was opened from (ref=search-standalone).
        "seek.com.au" to setOf("ref"),
        // Snapchat
        //   share_id identifies the share on profile links.
        "snapchat.com" to setOf("share_id"),
    )

    /** Params only stripped on some pages of a site (see UrlCleaner.pathMatches). */
    val SITE_PATH_PARAMS: List<SitePathParams> = listOf(
        // Amazon product pages
        //   keywords on a product link is what you searched for to find it, and srs the store page it was opened from. Only stripped on product pages: on search links (/s?keywords=...) keywords is the query, and srs can pick the store being browsed (#15). /-/<lang>/ paths are the same pages in another language.
        SitePathParams(listOf("amazon.*"), listOf("/dp/*/**", "/*/dp/*/**", "/gp/product/*/**", "/gp/aw/d/*/**", "/-/*/dp/*/**", "/-/*/*/dp/*/**", "/-/*/gp/product/*/**", "/-/*/gp/aw/d/*/**"), setOf("keywords", "srs")),
        // Pinterest pin pages
        //   Who shared the pin. Only stripped on /pin/<id>/ pages: on group-board and sign-up links they are the invite.
        SitePathParams(listOf("pinterest.*"), listOf("/pin/*/**"), setOf("invite_code", "sender")),
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
    )

    /** Short links that live on a path of a normal site (see UrlCleaner.pathMatches). */
    val SHORT_LINK_PATHS: List<ShortLinkPath> = listOf(
        // Reddit
        //   App share links like reddit.com/r/<sub>/s/<code>; the full post link carries share_id and utm_*.
        ShortLinkPath(listOf("reddit.com"), listOf("/r/*/s/*")),
        // Facebook
        //   Share links like facebook.com/share/p/<code>/ and /share/r/<code>/.
        ShortLinkPath(listOf("facebook.com"), listOf("/share/*", "/share/*/*")),
        // Mailchimp
        //   Newsletter click links on <account>.<dc>.list-manage.com. The e= param identifies the subscriber, so resolving replaces it with the destination. Resolving counts as a click by the person sharing. identifiesYou: if it redirects straight to a sign-in page, that page is shared rather than this link.
        ShortLinkPath(listOf("list-manage.com"), listOf("/track/click"), identifiesYou = true),
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
        // Bing search results
        //   Bing's result links carry the real link in u= as "a1" followed by unpadded base64url.
        RedirectWrapper(listOf("bing.com"), listOf("/ck/a"), listOf("u"), base64Prefix = "a1"),
        // Google cookie consent
        //   Resolving a maps.app.goo.gl or youtu.be link from a cookie-less device (e.g. in the EU) can land here; continue= is the real link. Google only continues to its own sites, so other targets are left alone.
        RedirectWrapper(listOf("consent.google.com", "consent.youtube.com"), listOf("/ml", "/m"), listOf("continue"), targetSites = listOf("google.*", "youtube.com")),
        // Facebook sign-in
        //   Resolving a Facebook short link without being signed in can land here; next= is the real link. Facebook only continues to its own pages, so other targets are left alone.
        RedirectWrapper(listOf("facebook.com"), listOf("/login/", "/login.php"), listOf("next"), targetSites = listOf("facebook.com")),
        // AliExpress share page
        //   Where a.aliexpress.com share links land: a share page whose redirectUrl= is the product link.
        RedirectWrapper(listOf("star.aliexpress.com"), listOf("/share/share.htm"), listOf("redirectUrl"), targetSites = listOf("aliexpress.*")),
    )

    /** Redirect links that carry the real link in their path; unwrapped offline. */
    val PATH_WRAPPERS: List<PathWrapper> = listOf(
        // Google AMP viewer
        //   google.com/amp/s/<host>/<path> shows another site's AMP page; the original is https://<host>/<path>.
        PathWrapper(listOf("google.*"), "/amp/s/", "https"),
    )

    /** Sign-in and consent pages: a short link that redirects to one stops at the hop before. */
    val DEAD_END_PAGES: List<SitePaths> = listOf(
        // Google and YouTube cookie consent
        SitePaths(listOf("consent.google.com", "consent.youtube.com"), listOf("/**")),
        // Google sign-in
        //   Only the interactive sign-in pages: other accounts.google.com pages (CheckCookie, ...) can pass a browser straight on to the content.
        SitePaths(listOf("accounts.google.com"), listOf("/ServiceLogin/**", "/signin/**", "/v3/signin/**", "/AccountChooser/**", "/InteractiveLogin/**")),
        // Facebook sign-in
        SitePaths(listOf("facebook.com"), listOf("/login/**", "/login.php")),
        // Instagram sign-in
        SitePaths(listOf("instagram.com"), listOf("/accounts/login/**")),
        // LinkedIn sign-in wall
        SitePaths(listOf("linkedin.com"), listOf("/authwall/**", "/login/**", "/uas/login/**")),
        // X / Twitter sign-in
        SitePaths(listOf("x.com", "twitter.com"), listOf("/login/**", "/i/flow/login/**")),
        // Reddit sign-in
        SitePaths(listOf("reddit.com"), listOf("/login/**", "/account/login/**")),
        // TikTok sign-in
        SitePaths(listOf("tiktok.com"), listOf("/login/**")),
        // Amazon sign-in
        SitePaths(listOf("amazon.*"), listOf("/ap/signin/**")),
    )
}

/**
 * A redirect on [sites] at [paths] (a trailing "*" matches any rest) whose first valid [params] value is the real
 * link: percent-encoded, or if [base64Prefix] is set, that prefix followed by the link in unpadded base64url.
 * If [targetSites] is set, the real link must be on one of them, or the wrapper is left alone.
 */
internal data class RedirectWrapper(
    val sites: List<String>,
    val paths: List<String>,
    val params: List<String>,
    val base64Prefix: String? = null,
    val targetSites: List<String>? = null,
)

/** A redirect on [sites] whose path after [prefix] is the real link, without its [scheme]. */
internal data class PathWrapper(val sites: List<String>, val prefix: String, val scheme: String)

/**
 * Short links on [sites] whose path matches one of [paths] (see UrlCleaner.pathMatches). If [identifiesYou],
 * the link itself identifies the person sharing it, so it's never kept in place of a sign-in page.
 */
internal data class ShortLinkPath(val sites: List<String>, val paths: List<String>, val identifiesYou: Boolean = false)

/** [params] stripped on [sites], but only where the path matches one of [paths] (see UrlCleaner.pathMatches). */
internal data class SitePathParams(val sites: List<String>, val paths: List<String>, val params: Set<String>)

/** Pages on [sites] whose path matches one of [paths] (see UrlCleaner.pathMatches). */
internal data class SitePaths(val sites: List<String>, val paths: List<String>)
