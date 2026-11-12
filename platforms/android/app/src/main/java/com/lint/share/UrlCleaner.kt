package com.lint.share

import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.URISyntaxException
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException

/**
 * Strips known tracking query parameters from URLs found in shared text, after unwrapping any
 * known redirect link (e.g. google.com/url?q=...) to the real link inside it.
 */
object UrlCleaner {

    private val URL_REGEX = Regex("""https?://[^\s]+""")

    // The rules themselves (tracking params, prefixes, site-specific params) live in
    // shared/rules/rules.json and are generated into GeneratedRules.kt.

    private fun isTrackingParam(name: String, host: String?, path: String?): Boolean {
        if (GeneratedRules.TRACKING_PREFIXES.any { name.startsWith(it) } || name in GeneratedRules.TRACKING_PARAMS) {
            return true
        }
        val lowerHost = host?.lowercase() ?: return false
        return GeneratedRules.SITE_PARAMS.any { (domain, params) -> name in params && hostMatches(lowerHost, domain) } ||
            GeneratedRules.SITE_PATH_PARAMS.any { rule ->
                name in rule.params && onPage(lowerHost, path, rule.sites, rule.paths)
            }
    }

    /** True if [host] matches one of [sites] and [path] (raw, percent-encoded) one of [paths]. */
    internal fun onPage(host: String, path: String?, sites: List<String>, paths: List<String>): Boolean {
        if (sites.none { hostMatches(host, it) }) return false
        val segments = (path ?: "").trim('/').split('/')
        return paths.any { pathMatches(segments, it) }
    }

    /**
     * True if a path's [segments] (split on "/", leading and trailing slashes trimmed) match
     * [pattern]: "/"-separated segments, each a name to match exactly or "*" for any one non-empty
     * segment, optionally ending in "**" for any rest of the path (including none).
     */
    internal fun pathMatches(segments: List<String>, pattern: String): Boolean {
        val wanted = pattern.trim('/').split('/')
        val anyRest = wanted.last() == "**"
        val fixed = if (anyRest) wanted.dropLast(1) else wanted
        if (if (anyRest) segments.size < fixed.size else segments.size != fixed.size) return false
        return fixed.indices.all { i -> segments[i].isNotEmpty() && (fixed[i] == "*" || fixed[i] == segments[i]) }
    }

    /**
     * True if [host] is [domain] or one of its subdomains. A [domain] ending in ".*" (e.g.
     * "eventbrite.*") instead matches that name followed by a country ending: "com", a two-letter
     * country code, or "com."/"co." plus one (so eventbrite.com, eventbrite.ca, eventbrite.com.au,
     * eventbrite.co.uk), plus subdomains of those. Lookalikes like noteventbrite.com or
     * eventbrite.evil.com don't match.
     */
    internal fun hostMatches(host: String, domain: String): Boolean {
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
     * Unwraps known redirect links (Gmail's google.com/url?q=..., l.facebook.com/l.php?u=...,
     * Outlook Safe Links, ...) to the real link they point at, entirely offline. Wrappers inside
     * wrappers are unwrapped too. Anything that isn't a known wrapper with a valid http(s) link
     * inside is returned unchanged.
     */
    fun unwrap(url: String): String {
        var current = url
        repeat(MAX_UNWRAP_DEPTH) { current = unwrapOnce(current) ?: return current }
        return current
    }

    private const val MAX_UNWRAP_DEPTH = 5

    private fun unwrapOnce(url: String): String? {
        val uri = try { URI(url) } catch (e: URISyntaxException) { return null }
        val host = uri.host?.lowercase() ?: return null
        val path = uri.rawPath.takeUnless { it.isNullOrEmpty() } ?: "/"

        for (wrapper in GeneratedRules.PATH_WRAPPERS) {
            if (wrapper.sites.none { hostMatches(host, it) } || !path.startsWith(wrapper.prefix)) continue
            val rest = path.removePrefix(wrapper.prefix) +
                (uri.rawQuery?.let { "?$it" } ?: "") + (uri.rawFragment?.let { "#$it" } ?: "")
            return validTarget("${wrapper.scheme}://$rest")
        }

        val pairs = uri.rawQuery?.split("&") ?: return null
        for (wrapper in GeneratedRules.REDIRECT_WRAPPERS) {
            if (wrapper.sites.none { hostMatches(host, it) } || wrapper.paths.none { wrapperPathMatches(path, it) }) continue
            for (param in wrapper.params) {
                val pair = pairs.firstOrNull { it.startsWith("$param=") } ?: continue
                val value = pair.substringAfter("=")
                val prefix = wrapper.base64Prefix
                val target = (if (prefix != null) base64UrlDecode(value, prefix) else percentDecode(value)) ?: continue
                val valid = validTarget(target) ?: continue
                if (wrapper.targetSites == null || onSite(valid, wrapper.targetSites)) return valid
            }
        }
        return null
    }

    /** Redirect wrapper paths match exactly, or as a prefix when they end in "*". */
    private fun wrapperPathMatches(path: String, pattern: String): Boolean =
        if (pattern.endsWith("*")) path.startsWith(pattern.dropLast(1)) else path == pattern

    /** True if [url]'s host matches one of [sites] (same matching as site rules). */
    private fun onSite(url: String, sites: List<String>): Boolean {
        val host = try { URI(url).host?.lowercase() } catch (e: URISyntaxException) { null } ?: return false
        return sites.any { hostMatches(host, it) }
    }

    /**
     * [target] if it's an http(s) link that parses with a host, otherwise null. Whitespace, control
     * and invisible format characters (e.g. U+202E, which reverses how text displays) are refused,
     * matching iOS's CharacterSet.controlCharacters.
     */
    private fun validTarget(target: String): String? {
        val lower = target.lowercase()
        if (!lower.startsWith("http://") && !lower.startsWith("https://")) return null
        if (target.any { it.isWhitespace() || it.isISOControl() }) return null
        if (target.codePoints().anyMatch { Character.getType(it) == Character.FORMAT.toInt() }) return null
        val uri = try { URI(target) } catch (e: URISyntaxException) { return null }
        return if (uri.host.isNullOrEmpty()) null else target
    }

    /**
     * Decodes [value] if it's [prefix] followed by unpadded base64url (Bing's u=a1aHR0c... form), or
     * null if it isn't or the bytes aren't valid UTF-8. Never falls back to percent-decoding: a
     * wrapper that uses base64 always does.
     */
    private fun base64UrlDecode(value: String, prefix: String): String? {
        if (!value.startsWith(prefix)) return null
        // Hand-rolled rather than java.util.Base64, which needs API 26 (minSdk is 24).
        val bytes = ByteArrayOutputStream()
        var buffer = 0
        var bits = 0
        for (c in value.removePrefix(prefix).trimEnd('=')) {
            val sextet = when (c) {
                in 'A'..'Z' -> c - 'A'
                in 'a'..'z' -> c - 'a' + 26
                in '0'..'9' -> c - '0' + 52
                '-' -> 62
                '_' -> 63
                else -> return null
            }
            buffer = (buffer shl 6) or sextet
            bits += 6
            if (bits >= 8) {
                bits -= 8
                bytes.write((buffer shr bits) and 0xFF)
            }
        }
        if (bits >= 6) return null // a lone trailing character can't encode a whole byte
        return try {
            Charsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes.toByteArray())).toString()
        } catch (e: CharacterCodingException) {
            null
        }
    }

    /** An ASCII hex digit's value, or -1. (Character.digit would also accept non-ASCII digits.) */
    private fun hexValue(c: Char): Int = when (c) {
        in '0'..'9' -> c - '0'
        in 'a'..'f' -> c - 'a' + 10
        in 'A'..'F' -> c - 'A' + 10
        else -> -1
    }

    /** Strict percent-decoding ("+" stays "+"): null if malformed or not valid UTF-8. */
    private fun percentDecode(value: String): String? {
        val bytes = ByteArrayOutputStream()
        var i = 0
        while (i < value.length) {
            if (value[i] == '%') {
                if (i + 2 >= value.length) return null
                val hi = hexValue(value[i + 1])
                val lo = hexValue(value[i + 2])
                if (hi < 0 || lo < 0) return null
                bytes.write(hi * 16 + lo)
                i += 3
            } else {
                val next = value.indexOf('%', i).let { if (it < 0) value.length else it }
                bytes.write(value.substring(i, next).toByteArray(Charsets.UTF_8))
                i = next
            }
        }
        return try {
            Charsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes.toByteArray())).toString()
        } catch (e: CharacterCodingException) {
            null
        }
    }

    /**
     * Unwraps [url] if it's a known redirect link (see [unwrap]), then removes tracking query
     * parameters, preserving any non-tracking query parameters and the fragment. Returns null if
     * the URL can't be parsed.
     */
    fun cleanUrl(url: String): String? {
        val target = unwrap(url)
        val uri = try {
            URI(target)
        } catch (e: URISyntaxException) {
            return null
        }

        val rawQuery = uri.rawQuery ?: return target

        val keptPairs = rawQuery.split("&")
            .filter { it.isNotEmpty() }
            .filter { pair ->
                val name = pair.substringBefore("=")
                !isTrackingParam(name, uri.host, uri.rawPath)
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
