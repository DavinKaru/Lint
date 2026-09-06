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
}
