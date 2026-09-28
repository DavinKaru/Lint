import Testing
@testable import LintCore

private typealias HopResponse = ShortLinkResolver.HopResponse

private struct UnexpectedUrl: Error {
    let url: String
}

/// Builds a fetcher from a fixed url -> response table, failing on anything not in it.
private func fetcher(_ responses: [String: HopResponse]) -> ShortLinkResolver.HopFetcher {
    { url in
        guard let response = responses[url] else { throw UnexpectedUrl(url: url) }
        return response
    }
}

/// Counts fetcher calls across concurrency domains.
private actor CallCounter {
    var count = 0
    func increment() { count += 1 }
}

struct ShortLinkResolverTests {

    @Test func resolvesASimpleSingleHopRedirect() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://a.co/d/abc123",
            fetcher: fetcher([
                "https://a.co/d/abc123": HopResponse(statusCode: 301, location: "https://www.amazon.com/dp/B000000000"),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.amazon.com/dp/B000000000": HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == "https://www.amazon.com/dp/B000000000")
    }

    @Test func followsMultipleHopsCorrectly() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://amzn.to/xyz",
            fetcher: fetcher([
                "https://amzn.to/xyz": HopResponse(statusCode: 301, location: "https://www.amazon.com/gp/1"),
                "https://www.amazon.com/gp/1": HopResponse(statusCode: 302, location: "https://www.amazon.com/gp/2"),
                "https://www.amazon.com/gp/2": HopResponse(statusCode: 302, location: "https://www.amazon.com/dp/B111111111?ref=abc"),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.amazon.com/dp/B111111111?ref=abc": HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == "https://www.amazon.com/dp/B111111111?ref=abc")
    }

    @Test func stopsAndReturnsTheOriginalUrlAfterExceedingMaxHops() async {
        let counter = CallCounter()

        let result = await ShortLinkResolver.followRedirects(
            from: "https://amzn.to/loop",
            fetcher: { url in
                await counter.increment()
                return HopResponse(statusCode: 301, location: "\(url)/next")
            },
            maxHops: 5
        )

        #expect(result == "https://amzn.to/loop")
        #expect(await counter.count == 5)
    }

    @Test func returnsTheOriginalUrlOnANon3xxResponse() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://a.co/d/gone",
            fetcher: { _ in HopResponse(statusCode: 404, location: nil) }
        )

        #expect(result == "https://a.co/d/gone")
    }

    @Test func returnsTheOriginalUrlWhenNoLocationHeaderIsPresent() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://a.co/d/broken",
            fetcher: { _ in HopResponse(statusCode: 301, location: nil) }
        )

        #expect(result == "https://a.co/d/broken")
    }

    @Test func matchesAllKnownShortLinkDomains() {
        #expect(ShortLinkResolver.isKnownShortLink("https://amzn.to/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://amzn.asia/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://a.co/d/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://A.CO/d/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://youtu.be/dQw4w9WgXcQ"))
        #expect(ShortLinkResolver.isKnownShortLink("https://t.co/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://fb.watch/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://spoti.fi/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://vm.tiktok.com/abc123"))
        #expect(ShortLinkResolver.isKnownShortLink("https://vt.tiktok.com/abc123"))
    }

    @Test func doesNotMatchLookalikeOrAlreadyFullUrls() {
        #expect(!ShortLinkResolver.isKnownShortLink("https://notamzn.to/abc123"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://a.co.evil.com/abc123"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://www.amazon.com/dp/B000000000"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://twitter.com/user/status/123"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://www.facebook.com/watch/?v=123"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://open.spotify.com/track/abc123"))
        #expect(!ShortLinkResolver.isKnownShortLink("https://www.tiktok.com/@user/video/123"))
    }

    @Test func resolvesAFacebookFbWatchRedirect() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://fb.watch/abc123",
            fetcher: fetcher([
                "https://fb.watch/abc123": HopResponse(statusCode: 301, location: "https://www.facebook.com/watch/?v=1234567890"),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://www.facebook.com/watch/?v=1234567890": HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == "https://www.facebook.com/watch/?v=1234567890")
    }

    @Test func resolvesASpotifySpotiFiRedirect() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://spoti.fi/abc123",
            fetcher: fetcher([
                "https://spoti.fi/abc123": HopResponse(statusCode: 301, location: "https://open.spotify.com/track/1a2b3c?si=xyz789"),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                "https://open.spotify.com/track/1a2b3c?si=xyz789": HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == "https://open.spotify.com/track/1a2b3c?si=xyz789")
    }

    @Test func resolvesATiktokVmTiktokComRedirect() async {
        let destination = "https://www.tiktok.com/@user/video/1234567890?is_from_webapp=1&sender_device=pc"
        let result = await ShortLinkResolver.followRedirects(
            from: "https://vm.tiktok.com/abc123",
            fetcher: fetcher([
                "https://vm.tiktok.com/abc123": HopResponse(statusCode: 301, location: destination),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                destination: HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == destination)
    }

    @Test func resolvesATiktokVtTiktokComRedirect() async {
        let destination = "https://www.tiktok.com/@user/video/1234567890?_r=1&_t=8abcde"
        let result = await ShortLinkResolver.followRedirects(
            from: "https://vt.tiktok.com/abc123",
            fetcher: fetcher([
                "https://vt.tiktok.com/abc123": HopResponse(statusCode: 301, location: destination),
                // Terminal fetch confirming the resolved URL doesn't redirect further.
                destination: HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == destination)
    }

    // iOS-only: Location headers are often relative, so check they resolve against the current hop.

    @Test func resolvesRelativeLocationHeaders() async {
        let result = await ShortLinkResolver.followRedirects(
            from: "https://youtu.be/abc",
            fetcher: fetcher([
                "https://youtu.be/abc": HopResponse(statusCode: 301, location: "https://www.youtube.com/watch?v=abc"),
                "https://www.youtube.com/watch?v=abc": HopResponse(statusCode: 302, location: "/watch?v=abc&app=m"),
                "https://www.youtube.com/watch?v=abc&app=m": HopResponse(statusCode: 200, location: nil),
            ])
        )

        #expect(result == "https://www.youtube.com/watch?v=abc&app=m")
    }
}
