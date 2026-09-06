package com.lint.share

import com.lint.share.ShortLinkResolver.HopResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShortLinkResolverTest {

    @Test
    fun `resolves a simple single-hop redirect`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://a.co/d/abc123" -> HopResponse(301, "https://www.amazon.com/dp/B000000000")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.amazon.com/dp/B000000000" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://a.co/d/abc123", fetcher)

        assertEquals("https://www.amazon.com/dp/B000000000", result)
    }

    @Test
    fun `follows multiple hops correctly`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://amzn.to/xyz" -> HopResponse(301, "https://www.amazon.com/gp/1")
                "https://www.amazon.com/gp/1" -> HopResponse(302, "https://www.amazon.com/gp/2")
                "https://www.amazon.com/gp/2" -> HopResponse(302, "https://www.amazon.com/dp/B111111111?ref=abc")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.amazon.com/dp/B111111111?ref=abc" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://amzn.to/xyz", fetcher)

        assertEquals("https://www.amazon.com/dp/B111111111?ref=abc", result)
    }

    @Test
    fun `stops and returns the original url after exceeding max hops`() {
        var calls = 0
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            calls++
            HopResponse(301, "$url/next")
        }

        val result = ShortLinkResolver.followRedirects("https://amzn.to/loop", fetcher, maxHops = 5)

        assertEquals("https://amzn.to/loop", result)
        assertEquals(5, calls)
    }

    @Test
    fun `returns the original url on a non-3xx response`() {
        val fetcher = ShortLinkResolver.HopFetcher { HopResponse(404, null) }

        val result = ShortLinkResolver.followRedirects("https://a.co/d/gone", fetcher)

        assertEquals("https://a.co/d/gone", result)
    }

    @Test
    fun `returns the original url when no location header is present`() {
        val fetcher = ShortLinkResolver.HopFetcher { HopResponse(301, null) }

        val result = ShortLinkResolver.followRedirects("https://a.co/d/broken", fetcher)

        assertEquals("https://a.co/d/broken", result)
    }

    @Test
    fun `matches all known short link domains`() {
        assertTrue(ShortLinkResolver.isKnownShortLink("https://amzn.to/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://amzn.asia/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://a.co/d/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://A.CO/d/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://youtu.be/dQw4w9WgXcQ"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://t.co/abc123"))
    }

    @Test
    fun `does not match lookalike or already-full urls`() {
        assertFalse(ShortLinkResolver.isKnownShortLink("https://notamzn.to/abc123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://a.co.evil.com/abc123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.amazon.com/dp/B000000000"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://twitter.com/user/status/123"))
    }
}
