import Testing
@testable import LintCore

struct UrlCleanerTests {

    @Test func stripsKnownTrackingParams() {
        let input = "https://example.com/article?utm_source=twitter&utm_medium=social&fbclid=abc123"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/article")
    }

    @Test func preservesUnknownQueryParams() {
        let input = "https://example.com/search?q=kotlin&utm_source=twitter"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/search?q=kotlin")
    }

    @Test func handlesUrlWithNoQueryString() {
        let input = "https://example.com/article"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/article")
    }

    @Test func handlesTextWithNoUrlPresent() {
        let input = "just some text, no link here"
        #expect(UrlCleaner.cleanFirstUrl(in: input) == input)
    }

    @Test func preservesFragment() {
        let input = "https://example.com/article?utm_source=twitter#section-2"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/article#section-2")
    }

    @Test func cleansFirstUrlFoundWithinSharedText() {
        let input = "Check this out: https://example.com/page?gclid=xyz&keep=1 thanks!"
        let expected = "Check this out: https://example.com/page?keep=1 thanks!"
        #expect(UrlCleaner.cleanFirstUrl(in: input) == expected)
    }

    @Test func stripsGoogleShoppingSrsltidParam() {
        let input = "https://global.gullylabs.com/?srsltid=AfmBOorKICbL9x5psNN1MHBeoHeSkEY2KBQTU71NgfpNuIpFXeSN8lQW"
        #expect(UrlCleaner.cleanUrl(input) == "https://global.gullylabs.com/")
    }

    @Test func stripsMatomoMtmPrefixedParams() {
        let input = "https://example.com/article?mtm_campaign=launch&mtm_source=newsletter&keep=1"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/article?keep=1")
    }

    @Test func stripsYoutubeFeatureReferralParam() {
        let input = "https://m.youtube.com/watch?v=jD-3zMQmjTY&feature=youtu.be"
        #expect(UrlCleaner.cleanUrl(input) == "https://m.youtube.com/watch?v=jD-3zMQmjTY")
    }

    @Test func stripsSpotifySiTrackingToken() {
        let input = "https://open.spotify.com/track/1a2b3c?si=xyz789"
        #expect(UrlCleaner.cleanUrl(input) == "https://open.spotify.com/track/1a2b3c")
    }

    @Test func stripsTiktokShareTrackingParams() {
        let input = "https://www.tiktok.com/@user/video/1234567890" +
            "?is_from_webapp=1&sender_device=pc&web_id=42&share_app_id=1233" +
            "&share_link_id=abc&share_item_id=def&u_code=ghi&_r=1&_t=8abcde"
        #expect(UrlCleaner.cleanUrl(input) == "https://www.tiktok.com/@user/video/1234567890")
    }

    @Test func stripsYoutubeSiShareToken() {
        let input = "https://youtu.be/jD-3zMQmjTY?si=AbCdEf123"
        #expect(UrlCleaner.cleanUrl(input) == "https://youtu.be/jD-3zMQmjTY")
    }

    @Test func hostScopedParamsMatchSubdomains() {
        let input = "https://music.youtube.com/watch?v=abc&si=xyz&feature=share"
        #expect(UrlCleaner.cleanUrl(input) == "https://music.youtube.com/watch?v=abc")
    }

    @Test func preservesHostScopedParamsOnUnrelatedSites() {
        let input = "https://example.com/page?feature=beta&si=1&_t=2&_r=3&web_id=4"
        #expect(UrlCleaner.cleanUrl(input) == input)
    }

    @Test func preservesHostScopedParamsOnLookalikeHosts() {
        let input = "https://nottiktok.com/page?_t=abc&_r=1"
        #expect(UrlCleaner.cleanUrl(input) == input)
    }

    // iOS-only: the Swift port works on the raw string, so check nothing else gets re-encoded.

    @Test func preservesPercentEncodingAndParamOrder() {
        let input = "https://example.com/a%20b?z=1&q=caf%C3%A9&utm_source=x&a=%2F#frag%20ment"
        #expect(UrlCleaner.cleanUrl(input) == "https://example.com/a%20b?z=1&q=caf%C3%A9&a=%2F#frag%20ment")
    }

    @Test func handlesMultipleUrlsInTextOnlyCleaningTheFirst() {
        let input = "a https://x.com/?fbclid=1 b https://y.com/?fbclid=2"
        #expect(UrlCleaner.cleanFirstUrl(in: input) == "a https://x.com/ b https://y.com/?fbclid=2")
    }

    @Test func handlesEmojiAroundTheUrl() {
        let input = "🎉👨‍👩‍👧 https://x.com/?fbclid=1&a=b 🎉"
        #expect(UrlCleaner.cleanFirstUrl(in: input) == "🎉👨‍👩‍👧 https://x.com/?a=b 🎉")
    }

    @Test func preservesGoogleMapsPlaceCid() {
        let input = "https://maps.google.com/?cid=1234567890&utm_source=share"
        #expect(UrlCleaner.cleanUrl(input) == "https://maps.google.com/?cid=1234567890")
    }

    @Test func preservesGoogleCalendarEventEid() {
        let input = "https://calendar.google.com/calendar/event?eid=abc123&utm_medium=email"
        #expect(UrlCleaner.cleanUrl(input) == "https://calendar.google.com/calendar/event?eid=abc123")
    }

    @Test func stripsFacebookEidTrackingParam() {
        let input = "https://www.facebook.com/events/123?eid=ARBxyz&ref=share"
        #expect(UrlCleaner.cleanUrl(input) == "https://www.facebook.com/events/123")
    }
}
