package com.lint.share

import java.net.URI
import java.net.URISyntaxException

/**
 * Strips known tracking query parameters from URLs found in shared text.
 */
object UrlCleaner {

    private val URL_REGEX = Regex("""https?://[^\s]+""")

    // The rules themselves (tracking params, prefixes, site-specific params) live in
    // shared/rules/rules.json and are generated into GeneratedRules.kt.

    private fun isTrackingParam(name: String, host: String?): Boolean {
        if (GeneratedRules.TRACKING_PREFIXES.any { name.startsWith(it) } || name in GeneratedRules.TRACKING_PARAMS) {
            return true
        }
        val lowerHost = host?.lowercase() ?: return false
        return GeneratedRules.SITE_PARAMS.any { (domain, params) ->
            name in params && hostMatches(lowerHost, domain)
        }
    }

    /**
     * True if [host] is [domain] or one of its subdomains. A [domain] ending in ".*" (e.g.
     * "eventbrite.*") instead matches that name followed by a country ending: "com", a two-letter
     * country code, or "com."/"co." plus one (so eventbrite.com, eventbrite.ca, eventbrite.com.au,
     * eventbrite.co.uk), plus subdomains of those. Lookalikes like noteventbrite.com or
     * eventbrite.evil.com don't match.
     */
    private fun hostMatches(host: String, domain: String): Boolean {
        if (!domain.endsWith(".*")) return host == domain || host.endsWith(".$domain")
        val name = Regex.escape(domain.removeSuffix(".*"))
        return Regex("""^(.+\.)?$name\.(com|[a-z]{2}|(com|co)\.[a-z]{2})$""").matches(host)
    }

    /** The first http(s) URL found in some text, and where it sits within that text. */
    data class UrlMatch(val range: IntRange, val url: String)

    /** Returns the first http(s) URL found in [text] along with its range, or null if none is present. */
    fun findFirstUrl(text: String): UrlMatch? {
        val match = URL_REGEX.find(text) ?: return null
        return UrlMatch(match.range, match.value)
    }

    /**
     * Finds the first http(s) URL in [text] and returns [text] with that URL's tracking
     * query parameters removed. If no URL is found, returns [text] unchanged.
     */
    fun cleanFirstUrl(text: String): String {
        val match = findFirstUrl(text) ?: return text
        val cleaned = cleanUrl(match.url) ?: return text
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
                !isTrackingParam(name, uri.host)
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
