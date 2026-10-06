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

    @Test func stripsEventbriteAffFromAnOrganiserLink() {
        let input = "https://www.eventbrite.com/o/55943994763?aff=ebdsshandroid"
        #expect(UrlCleaner.cleanUrl(input) == "https://www.eventbrite.com/o/55943994763")
    }

    @Test func stripsEventbriteShareParamsFromAnEventSharedAsText() {
        let input = "South Asian Queerspace October Meet Up\n\nDate: 17 oct • 13:00\n\n" +
            "https://www.eventbrite.com.au/e/south-asian-queerspace-october-meet-up-tickets-2002707650494" +
            "?aff=ebdsshsms&utm_share_source=listing_android&sg=3de21ae99fe972aeffdddd25fd1744bc49bc3ce1f698a860d0c15acf48c78b311617f2f8a2a569aae6be479a1146e57d98d07f3a60a63faa195df17671643f110c8d45e59dcdb050059ea6378eec"
        let expected = "South Asian Queerspace October Meet Up\n\nDate: 17 oct • 13:00\n\n" +
            "https://www.eventbrite.com.au/e/south-asian-queerspace-october-meet-up-tickets-2002707650494"
        #expect(UrlCleaner.cleanFirstUrl(in: input) == expected)
    }

    @Test func stripsEventbriteParamsOnOtherCountryDomains() {
        #expect(UrlCleaner.cleanUrl("https://www.eventbrite.co.uk/e/1?aff=x&sg=y") == "https://www.eventbrite.co.uk/e/1")
        #expect(UrlCleaner.cleanUrl("https://www.eventbrite.ca/e/1?aff=x") == "https://www.eventbrite.ca/e/1")
        #expect(UrlCleaner.cleanUrl("https://eventbrite.com.br/e/1?sg=y") == "https://eventbrite.com.br/e/1")
    }

    @Test(arguments: [
        "https://example.com/page?aff=partner1&sg=group2",
        "https://noteventbrite.com/e/1?aff=x&sg=y",
        "https://eventbrite.evil.com/e/1?aff=x&sg=y",
    ])
    func preservesAffAndSgOutsideEventbrite(_ input: String) {
        #expect(UrlCleaner.cleanUrl(input) == input)
    }
}
