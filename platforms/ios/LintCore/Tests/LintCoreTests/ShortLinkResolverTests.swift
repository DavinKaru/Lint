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

    // Budget and failure handling, matching Android's resolveOverNetwork.

    @Test func failedLaterHopKeepsTheUrlReachedSoFar() async {
        let result = await ShortLinkResolver.resolve("https://vm.tiktok.com/abc", budget: .seconds(3)) { url, _ in
            switch url {
            case "https://vm.tiktok.com/abc":
                HopResponse(statusCode: 301, location: "https://www.tiktok.com/@u/video/1?_t=x")
            default:
                // e.g. a timeout on the confirmation hop.
                HopResponse(statusCode: -1, location: nil)
            }
        }

        #expect(result == "https://www.tiktok.com/@u/video/1?_t=x")
    }

    @Test func failedFirstHopFallsBackToTheShortLink() async {
        let result = await ShortLinkResolver.resolve("https://youtu.be/abc", budget: .seconds(3)) { _, _ in
            HopResponse(statusCode: -1, location: nil)
        }

        #expect(result == "https://youtu.be/abc")
    }

    @Test func spentBudgetKeepsTheUrlReachedSoFar() async {
        // Every hop redirects and takes 40ms; with a 100ms budget the chain gets partway through
        // before the budget runs out, and should keep that progress rather than start over.
        let result = await ShortLinkResolver.resolve("https://youtu.be/0", budget: .milliseconds(100)) { url, _ in
            try? await Task.sleep(for: .milliseconds(40))
            let next = Int(url.split(separator: "/").last!)! + 1
            return HopResponse(statusCode: 301, location: "https://youtu.be/\(next)")
        }

        #expect(result != "https://youtu.be/0")
        #expect(["https://youtu.be/1", "https://youtu.be/2", "https://youtu.be/3"].contains(result))
    }

    @Test func hopsNeverGetMoreThanTheRemainingBudget() async {
        let timeouts = TimeoutRecorder()

        _ = await ShortLinkResolver.resolve("https://youtu.be/0", budget: .milliseconds(200)) { url, timeout in
            await timeouts.record(timeout)
            try? await Task.sleep(for: .milliseconds(80))
            let next = Int(url.split(separator: "/").last!)! + 1
            return HopResponse(statusCode: 301, location: "https://youtu.be/\(next)")
        }

        let recorded = await timeouts.values
        #expect(!recorded.isEmpty)
        #expect(recorded.allSatisfy { $0 <= .milliseconds(200) })
    }
}

private actor TimeoutRecorder {
    var values: [Duration] = []
    func record(_ value: Duration) { values.append(value) }
}
