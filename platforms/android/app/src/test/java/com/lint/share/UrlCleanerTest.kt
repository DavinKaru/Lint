package com.lint.share

import org.junit.Assert.assertEquals
import org.junit.Test

class UrlCleanerTest {

    @Test
    fun `strips known tracking params`() {
        val input = "https://example.com/article?utm_source=twitter&utm_medium=social&fbclid=abc123"
        assertEquals("https://example.com/article", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `preserves unknown query params`() {
        val input = "https://example.com/search?q=kotlin&utm_source=twitter"
        assertEquals("https://example.com/search?q=kotlin", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `handles url with no query string`() {
        val input = "https://example.com/article"
        assertEquals("https://example.com/article", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `handles text with no url present`() {
        val input = "just some text, no link here"
        assertEquals(input, UrlCleaner.cleanFirstUrl(input))
    }

    @Test
    fun `preserves fragment`() {
        val input = "https://example.com/article?utm_source=twitter#section-2"
        assertEquals("https://example.com/article#section-2", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `cleans first url found within shared text`() {
        val input = "Check this out: https://example.com/page?gclid=xyz&keep=1 thanks!"
        val expected = "Check this out: https://example.com/page?keep=1 thanks!"
        assertEquals(expected, UrlCleaner.cleanFirstUrl(input))
    }

    @Test
    fun `strips google shopping srsltid param`() {
        val input = "https://global.gullylabs.com/?srsltid=AfmBOorKICbL9x5psNN1MHBeoHeSkEY2KBQTU71NgfpNuIpFXeSN8lQW"
        assertEquals("https://global.gullylabs.com/", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips matomo mtm prefixed params`() {
        val input = "https://example.com/article?mtm_campaign=launch&mtm_source=newsletter&keep=1"
        assertEquals("https://example.com/article?keep=1", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips youtube feature referral param`() {
        val input = "https://m.youtube.com/watch?v=jD-3zMQmjTY&feature=youtu.be"
        assertEquals("https://m.youtube.com/watch?v=jD-3zMQmjTY", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips spotify si tracking token`() {
        val input = "https://open.spotify.com/track/1a2b3c?si=xyz789"
        assertEquals("https://open.spotify.com/track/1a2b3c", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips tiktok share tracking params`() {
        val input = "https://www.tiktok.com/@user/video/1234567890" +
            "?is_from_webapp=1&sender_device=pc&web_id=42&share_app_id=1233" +
            "&share_link_id=abc&share_item_id=def&u_code=ghi&_r=1&_t=8abcde"
        assertEquals("https://www.tiktok.com/@user/video/1234567890", UrlCleaner.cleanUrl(input))
    }
}
