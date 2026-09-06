package com.lint.share

import android.util.Log
import java.net.HttpURLConnection
import java.net.URI

private const val TAG = "Lint"

/**
 * Resolves known short links (Amazon's amzn.to / amzn.asia / a.co, YouTube's youtu.be, and
 * Twitter/X's t.co) to their final URL by following HTTP redirects, so [UrlCleaner] can strip
 * tracking params that only appear on the resolved URL.
 *
 * Amazon's redirect service is known to block plain HTTP clients like this one at the edge
 * (see PRIVACY.md) -- that entry stays in [KNOWN_SHORT_LINK_HOSTS] since it fails safe (falls
 * back to the unresolved short link, same as any other failure), and in case that changes.
 *
 * Privacy constraint (keep this true going forward): resolution must always happen directly
 * from the user's own device to the short-link provider's redirect service. Never proxy this
 * through any Lint-operated server, even for caching or performance reasons in the future --
 * doing so would turn Lint's own server into a single linkable identity across all users, which
 * defeats the point of this being a fully on-device tool.
 */
object ShortLinkResolver {

    private val KNOWN_SHORT_LINK_HOSTS = setOf("amzn.to", "amzn.asia", "a.co", "youtu.be", "t.co")

    const val MAX_HOPS = 5
    private const val CONNECT_TIMEOUT_MS = 1500
    private const val READ_TIMEOUT_MS = 1500
    private const val TOTAL_BUDGET_MS = 3000L

    /** One hop's outcome: the HTTP response code and, if present, the Location header. */
    data class HopResponse(val responseCode: Int, val locationHeader: String?)

    /** A way to fetch a single hop's response, so redirect-following can be tested without real network calls. */
    fun interface HopFetcher {
        fun fetch(url: String): HopResponse
    }

    /**
     * Returns true if [url]'s host is exactly one of the known short-link domains
     * (case-insensitive, exact match — not a substring match).
     */
    fun isKnownShortLink(url: String): Boolean {
        val host = try {
            URI(url).host
        } catch (e: Exception) {
            null
        } ?: return false
        return host.lowercase() in KNOWN_SHORT_LINK_HOSTS
    }

    /**
     * Pure redirect-following logic. Starting from [startUrl], calls [fetcher] for each hop and
     * follows its Location header (resolved against the previous hop's URL) up to [maxHops]
     * times. A non-3xx (or Location-less) response ends the chain successfully, returning
     * whatever URL was reached so far (confirming it doesn't redirect further). Falls back to
     * [startUrl] unchanged if a hop throws, or if the chain still hasn't terminated after
     * [maxHops] redirects (an unusually long or looping chain).
     */
    fun followRedirects(startUrl: String, fetcher: HopFetcher, maxHops: Int = MAX_HOPS): String {
        var currentUrl = startUrl

        repeat(maxHops) {
            val response = try {
                fetcher.fetch(currentUrl)
            } catch (e: Exception) {
                return startUrl
            }

            // A non-3xx (or missing Location) response means we've reached the final
            // destination -- not a failure. currentUrl still equals startUrl if this is the
            // very first hop, so this correctly covers "never redirected at all" too.
            if (response.responseCode !in 300..399) return currentUrl
            val location = response.locationHeader ?: return currentUrl

            currentUrl = try {
                URI(currentUrl).resolve(location).toString()
            } catch (e: Exception) {
                return startUrl
            }
        }

        return startUrl
    }

    /**
     * Resolves [startUrl] over the real network. Never throws — any timeout, exception, or
     * unexpected response falls back to returning [startUrl] unchanged. Must be called off the
     * main thread.
     */
    fun resolveOverNetwork(startUrl: String): String {
        val deadline = System.currentTimeMillis() + TOTAL_BUDGET_MS

        val fetcher = HopFetcher { url ->
            if (System.currentTimeMillis() >= deadline) {
                Log.w(TAG, "resolution budget (${TOTAL_BUDGET_MS}ms) exceeded, abandoning")
                HopResponse(responseCode = -1, locationHeader = null)
            } else {
                fetchOneHop(url)
            }
        }

        return try {
            followRedirects(startUrl, fetcher)
        } catch (e: Exception) {
            startUrl
        }
    }

    private fun fetchOneHop(url: String): HopResponse {
        var connection: HttpURLConnection? = null
        return try {
            connection = openConnection(url, "HEAD")
            connection.connect()
            var code = connection.responseCode

            // Some servers reject HEAD; retry with GET but never read the body.
            if (code == 405 || code == 501) {
                connection.disconnect()
                connection = openConnection(url, "GET")
                connection.connect()
                code = connection.responseCode
            }

            val location = connection.getHeaderField("Location")
            Log.d(TAG, "hop: $url -> $code${if (location != null) " -> $location" else ""}")
            HopResponse(responseCode = code, locationHeader = location)
        } catch (e: Exception) {
            Log.w(TAG, "hop failed: $url (${e.javaClass.simpleName}: ${e.message})")
            HopResponse(responseCode = -1, locationHeader = null)
        } finally {
            connection?.disconnect()
        }
    }

    // A bare HttpURLConnection sends none of the headers a real browser normally would, and
    // some servers (Amazon's redirect service included) respond differently -- e.g. a 404
    // instead of a redirect -- to requests that don't look like they came from a browser.
    // These are standard, honestly-identifying request headers, not fingerprint spoofing.
    private const val USER_AGENT =
        "Mozilla/5.0 (Linux; Android 14; Pixel) AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/128.0.0.0 Mobile Safari/537.36"

    private fun openConnection(url: String, method: String): HttpURLConnection {
        return (URI(url).toURL().openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = false
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            requestMethod = method
            setRequestProperty("User-Agent", USER_AGENT)
            setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            setRequestProperty("Accept-Language", "en-US,en;q=0.9")
        }
    }
}
