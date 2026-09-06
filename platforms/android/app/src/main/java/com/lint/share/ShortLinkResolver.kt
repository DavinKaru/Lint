package com.lint.share

import java.net.HttpURLConnection
import java.net.URI

/**
 * Resolves Amazon short links (amzn.to / amzn.asia / a.co) to their final product URL by
 * following HTTP redirects, so [UrlCleaner] can strip tracking params that only appear on the
 * resolved URL.
 *
 * Privacy constraint (keep this true going forward): resolution must always happen directly
 * from the user's own device to Amazon's redirect service. Never proxy this through any
 * Lint-operated server, even for caching or performance reasons in the future — doing so would
 * turn Lint's own server into a single linkable identity across all users, which defeats the
 * point of this being a fully on-device tool.
 */
object ShortLinkResolver {

    private val AMAZON_SHORT_LINK_HOSTS = setOf("amzn.to", "amzn.asia", "a.co")

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
     * Returns true if [url]'s host is exactly one of the known Amazon short-link domains
     * (case-insensitive, exact match — not a substring match).
     */
    fun isAmazonShortLink(url: String): Boolean {
        val host = try {
            URI(url).host
        } catch (e: Exception) {
            null
        } ?: return false
        return host.lowercase() in AMAZON_SHORT_LINK_HOSTS
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

            HopResponse(responseCode = code, locationHeader = connection.getHeaderField("Location"))
        } catch (e: Exception) {
            HopResponse(responseCode = -1, locationHeader = null)
        } finally {
            connection?.disconnect()
        }
    }

    private fun openConnection(url: String, method: String): HttpURLConnection {
        return (URI(url).toURL().openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = false
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            requestMethod = method
        }
    }
}
