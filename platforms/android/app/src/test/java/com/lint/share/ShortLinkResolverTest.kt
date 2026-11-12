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
        assertTrue(ShortLinkResolver.isKnownShortLink("https://fb.watch/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://spoti.fi/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://vm.tiktok.com/abc123"))
        assertTrue(ShortLinkResolver.isKnownShortLink("https://vt.tiktok.com/abc123"))
    }

    @Test
    fun `does not match lookalike or already-full urls`() {
        assertFalse(ShortLinkResolver.isKnownShortLink("https://notamzn.to/abc123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://a.co.evil.com/abc123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.amazon.com/dp/B000000000"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://twitter.com/user/status/123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.facebook.com/watch/?v=123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://open.spotify.com/track/abc123"))
        assertFalse(ShortLinkResolver.isKnownShortLink("https://www.tiktok.com/@user/video/123"))
    }

    @Test
    fun `resolves a facebook fb-watch redirect`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://fb.watch/abc123" -> HopResponse(301, "https://www.facebook.com/watch/?v=1234567890")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.facebook.com/watch/?v=1234567890" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://fb.watch/abc123", fetcher)

        assertEquals("https://www.facebook.com/watch/?v=1234567890", result)
    }

    @Test
    fun `resolves a spotify spoti-fi redirect`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://spoti.fi/abc123" -> HopResponse(301, "https://open.spotify.com/track/1a2b3c?si=xyz789")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://open.spotify.com/track/1a2b3c?si=xyz789" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://spoti.fi/abc123", fetcher)

        assertEquals("https://open.spotify.com/track/1a2b3c?si=xyz789", result)
    }

    @Test
    fun `resolves a tiktok vm-tiktok-com redirect`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://vm.tiktok.com/abc123" ->
                    HopResponse(301, "https://www.tiktok.com/@user/video/1234567890?is_from_webapp=1&sender_device=pc")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.tiktok.com/@user/video/1234567890?is_from_webapp=1&sender_device=pc" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://vm.tiktok.com/abc123", fetcher)

        assertEquals("https://www.tiktok.com/@user/video/1234567890?is_from_webapp=1&sender_device=pc", result)
    }

    @Test
    fun `resolves a tiktok vt-tiktok-com redirect`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://vt.tiktok.com/abc123" ->
                    HopResponse(301, "https://www.tiktok.com/@user/video/1234567890?_r=1&_t=8abcde")
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.tiktok.com/@user/video/1234567890?_r=1&_t=8abcde" -> HopResponse(200, null)
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        val result = ShortLinkResolver.followRedirects("https://vt.tiktok.com/abc123", fetcher)

        assertEquals("https://www.tiktok.com/@user/video/1234567890?_r=1&_t=8abcde", result)
    }

    @Test
    fun `stops at the hop before a sign-in page`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://fb.watch/abc123" -> HopResponse(302, "https://www.facebook.com/watch/?v=1234567890")
                "https://www.facebook.com/watch/?v=1234567890" -> HopResponse(302, "/login/?next=%2Fwatch%2F%3Fv%3D1234567890")
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        assertEquals("https://www.facebook.com/watch/?v=1234567890", ShortLinkResolver.followRedirects("https://fb.watch/abc123", fetcher))
    }

    @Test
    fun `keeps the short link when it redirects straight to a sign-in page`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://fb.watch/abc123" -> HopResponse(302, "https://www.facebook.com/login.php?next=%2Fwatch%2F")
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        assertEquals("https://fb.watch/abc123", ShortLinkResolver.followRedirects("https://fb.watch/abc123", fetcher))
    }

    @Test
    fun `takes the real link from a consent page that carries it in full`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://youtu.be/dQw4w9WgXcQ" -> HopResponse(
                    302,
                    "https://consent.youtube.com/m?continue=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ%26si%3Dabc&gl=AU",
                )
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        assertEquals(
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=abc",
            ShortLinkResolver.followRedirects("https://youtu.be/dQw4w9WgXcQ", fetcher),
        )
    }

    @Test
    fun `shares the sign-in page rather than a click link that identifies you`() {
        val start = "https://example.us1.list-manage.com/track/click?u=abc&id=def&e=SUBSCRIBER"
        val signIn = "https://www.facebook.com/login/?next=%2Fevents%2F1234567890"
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            if (url == start) HopResponse(302, signIn) else throw AssertionError("unexpected url: $url")
        }

        assertEquals(signIn, ShortLinkResolver.followRedirects(start, fetcher))
    }

    @Test
    fun `never takes a sign-in page out of a consent page`() {
        val fetcher = ShortLinkResolver.HopFetcher { url ->
            when (url) {
                "https://youtu.be/dQw4w9WgXcQ" -> HopResponse(301, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -> HopResponse(
                    302,
                    "https://consent.youtube.com/m?continue=https%3A%2F%2Faccounts.google.com%2FServiceLogin%3Fcontinue%3Dx",
                )
                else -> throw AssertionError("unexpected url: $url")
            }
        }

        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", ShortLinkResolver.followRedirects("https://youtu.be/dQw4w9WgXcQ", fetcher))
    }
}
