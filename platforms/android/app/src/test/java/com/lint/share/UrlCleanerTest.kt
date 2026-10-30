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

    @Test
    fun `strips youtube si share token`() {
        val input = "https://youtu.be/jD-3zMQmjTY?si=AbCdEf123"
        assertEquals("https://youtu.be/jD-3zMQmjTY", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `host-scoped params match subdomains`() {
        val input = "https://music.youtube.com/watch?v=abc&si=xyz&feature=share"
        assertEquals("https://music.youtube.com/watch?v=abc", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `preserves host-scoped params on unrelated sites`() {
        val input = "https://example.com/page?feature=beta&si=1&_t=2&_r=3&web_id=4"
        assertEquals(input, UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `preserves host-scoped params on lookalike hosts`() {
        val input = "https://nottiktok.com/page?_t=abc&_r=1"
        assertEquals(input, UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `preserves google maps place cid`() {
        val input = "https://maps.google.com/?cid=1234567890&utm_source=share"
        assertEquals("https://maps.google.com/?cid=1234567890", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `preserves google calendar event eid`() {
        val input = "https://calendar.google.com/calendar/event?eid=abc123&utm_medium=email"
        assertEquals("https://calendar.google.com/calendar/event?eid=abc123", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips facebook eid tracking param`() {
        val input = "https://www.facebook.com/events/123?eid=ARBxyz&ref=share"
        assertEquals("https://www.facebook.com/events/123", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips eventbrite aff from an organiser link`() {
        val input = "https://www.eventbrite.com/o/55943994763?aff=ebdsshandroid"
        assertEquals("https://www.eventbrite.com/o/55943994763", UrlCleaner.cleanUrl(input))
    }

    @Test
    fun `strips eventbrite share params from an event shared as text`() {
        val input = "South Asian Queerspace October Meet Up\n\nDate: 17 oct • 13:00\n\n" +
            "https://www.eventbrite.com.au/e/south-asian-queerspace-october-meet-up-tickets-2002707650494" +
            "?aff=ebdsshsms&utm_share_source=listing_android&sg=3de21ae99fe972aeffdddd25fd1744bc49bc3ce1f698a860d0c15acf48c78b311617f2f8a2a569aae6be479a1146e57d98d07f3a60a63faa195df17671643f110c8d45e59dcdb050059ea6378eec"
        val expected = "South Asian Queerspace October Meet Up\n\nDate: 17 oct • 13:00\n\n" +
            "https://www.eventbrite.com.au/e/south-asian-queerspace-october-meet-up-tickets-2002707650494"
        assertEquals(expected, UrlCleaner.cleanFirstUrl(input))
    }

    @Test
    fun `strips eventbrite params on other country domains`() {
        assertEquals("https://www.eventbrite.co.uk/e/1", UrlCleaner.cleanUrl("https://www.eventbrite.co.uk/e/1?aff=x&sg=y"))
        assertEquals("https://www.eventbrite.ca/e/1", UrlCleaner.cleanUrl("https://www.eventbrite.ca/e/1?aff=x"))
        assertEquals("https://eventbrite.com.br/e/1", UrlCleaner.cleanUrl("https://eventbrite.com.br/e/1?sg=y"))
    }

    @Test
    fun `preserves aff and sg outside eventbrite`() {
        for (input in listOf(
            "https://example.com/page?aff=partner1&sg=group2",
            "https://noteventbrite.com/e/1?aff=x&sg=y",
            "https://eventbrite.evil.com/e/1?aff=x&sg=y",
        )) {
            assertEquals(input, UrlCleaner.cleanUrl(input))
        }
    }
}
