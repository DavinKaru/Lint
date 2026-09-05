package com.lint.share

import java.net.URI
import java.net.URISyntaxException

/**
 * Strips known tracking query parameters from URLs found in shared text.
 */
object UrlCleaner {

    private val URL_REGEX = Regex("""https?://[^\s]+""")

    private val EXACT_TRACKING_PARAMS = setOf(
        // Original set
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid",
        "igshid", "igsh", "twclid", "ttclid", "yclid",
        "vero_id", "vero_conv",
        "mc_cid", "mc_eid",
        "mkt_tok", "_hsenc", "_hsmi",
        "ref", "ref_src", "si", "cid", "epik",
        // Google (Ads/Analytics/Shopping)
        "aqs", "cd", "ei", "iflsig", "pcampaignid", "rlz", "srsltid", "sxsrf", "uact", "ved",
        "_ga", "_gl",
        // Meta/Facebook
        "comment_tracking", "eav", "eid", "mibextid", "__tn__",
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
    )

    private val TRACKING_PREFIXES = listOf("utm_", "mtm_")

    private fun isTrackingParam(name: String): Boolean {
        return TRACKING_PREFIXES.any { name.startsWith(it) } || name in EXACT_TRACKING_PARAMS
    }

    /**
     * Finds the first http(s) URL in [text] and returns [text] with that URL's tracking
     * query parameters removed. If no URL is found, returns [text] unchanged.
     */
    fun cleanFirstUrl(text: String): String {
        val match = URL_REGEX.find(text) ?: return text
        val cleaned = cleanUrl(match.value) ?: return text
        return text.replaceRange(match.range, cleaned)
    }

    /**
     * Removes tracking query parameters from a single URL string, preserving any
     * non-tracking query parameters and the fragment. Returns null if the URL can't be parsed.
     */
    fun cleanUrl(url: String): String? {
        val uri = try {
            URI(url)
        } catch (e: URISyntaxException) {
            return null
        }

        val rawQuery = uri.rawQuery ?: return url

        val keptPairs = rawQuery.split("&")
            .filter { it.isNotEmpty() }
            .filter { pair ->
                val name = pair.substringBefore("=")
                !isTrackingParam(name)
            }

        val newQuery = keptPairs.joinToString("&")

        val builder = StringBuilder()
        builder.append(uri.scheme).append("://")
        if (uri.rawAuthority != null) builder.append(uri.rawAuthority)
        if (uri.rawPath != null) builder.append(uri.rawPath)
        if (newQuery.isNotEmpty()) builder.append("?").append(newQuery)
        if (uri.rawFragment != null) builder.append("#").append(uri.rawFragment)

        return builder.toString()
    }
}
