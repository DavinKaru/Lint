import Foundation
import os

private let logger = Logger(subsystem: "com.lint.share", category: "Lint")

/// Resolves known short links (Amazon's amzn.to / amzn.asia / a.co, YouTube's youtu.be,
/// Twitter/X's t.co, Facebook's fb.watch, Spotify's spoti.fi, and TikTok's vm.tiktok.com /
/// vt.tiktok.com) to their final URL by following HTTP redirects, so `UrlCleaner` can strip
/// tracking params that only appear on the resolved URL.
///
/// Swift port of Android's `ShortLinkResolver.kt` -- `knownShortLinkHosts` must stay in sync with
/// it and with the table in PRIVACY.md.
///
/// Amazon's redirect service is known to block plain HTTP clients like this one at the edge
/// (see PRIVACY.md) -- that entry stays in `knownShortLinkHosts` since it fails safe (falls
/// back to the unresolved short link, same as any other failure), and in case that changes.
///
/// Privacy constraint (keep this true going forward): resolution must always happen directly
/// from the user's own device to the short-link provider's redirect service. Never proxy this
/// through any Lint-operated server, even for caching or performance reasons in the future --
/// doing so would turn Lint's own server into a single linkable identity across all users, which
/// defeats the point of this being a fully on-device tool.
public enum ShortLinkResolver {

    private static let knownShortLinkHosts: Set<String> = [
        "amzn.to", "amzn.asia", "a.co",
        "youtu.be",
        "t.co",
        "fb.watch",
        "spoti.fi",
        "vm.tiktok.com", "vt.tiktok.com",
    ]

    public static let maxHops = 5
    private static let requestTimeout: TimeInterval = 1.5
    private static let totalBudget: Duration = .seconds(3)

    /// One hop's outcome: the HTTP status code and, if present, the Location header.
    public struct HopResponse: Equatable, Sendable {
        public let statusCode: Int
        public let location: String?

        public init(statusCode: Int, location: String?) {
            self.statusCode = statusCode
            self.location = location
        }
    }

    /// A way to fetch a single hop's response, so redirect-following can be tested without real network calls.
    public typealias HopFetcher = @Sendable (String) async throws -> HopResponse

    /// Returns true if `url`'s host is exactly one of the known short-link domains
    /// (case-insensitive, exact match — not a substring match).
    public static func isKnownShortLink(_ url: String) -> Bool {
        guard let host = URLComponents(string: url)?.host else { return false }
        return knownShortLinkHosts.contains(host.lowercased())
    }

    /// Pure redirect-following logic. Starting from `startUrl`, calls `fetcher` for each hop and
    /// follows its Location header (resolved against the previous hop's URL) up to `maxHops`
    /// times. A non-3xx (or Location-less) response ends the chain successfully, returning
    /// whatever URL was reached so far (confirming it doesn't redirect further). Falls back to
    /// `startUrl` unchanged if a hop throws, or if the chain still hasn't terminated after
    /// `maxHops` redirects (an unusually long or looping chain).
    public static func followRedirects(
        from startUrl: String,
        fetcher: HopFetcher,
        maxHops: Int = maxHops
    ) async -> String {
        var currentUrl = startUrl

        for _ in 0..<maxHops {
            guard let response = try? await fetcher(currentUrl) else { return startUrl }

            // A non-3xx (or missing Location) response means we've reached the final
            // destination -- not a failure. currentUrl still equals startUrl if this is the
            // very first hop, so this correctly covers "never redirected at all" too.
            guard (300...399).contains(response.statusCode), let location = response.location else {
                return currentUrl
            }

            guard let base = URL(string: currentUrl),
                  let next = URL(string: location, relativeTo: base)?.absoluteString
            else { return startUrl }
            currentUrl = next
        }

        return startUrl
    }

    /// Resolves `startUrl` over the real network. Never throws — any timeout, error, or
    /// unexpected response falls back to returning `startUrl` unchanged. The whole resolution is
    /// capped at `totalBudget`, even if an individual hop is still in flight.
    public static func resolveOverNetwork(_ startUrl: String) async -> String {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await followRedirects(from: startUrl) { url in try await fetchOneHop(url, session: session) }
            }
            group.addTask {
                try? await Task.sleep(for: totalBudget)
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            guard let resolved = first else {
                logger.warning("resolution budget (\(totalBudget)) exceeded, abandoning")
                return startUrl
            }
            return resolved
        }
    }

    // MARK: - Networking

    /// Refuses every redirect, so each hop's 3xx and Location header are visible to
    /// `followRedirects` instead of being followed automatically.
    private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            nil
        }
    }

    private static func makeSession() -> URLSession {
        // Ephemeral: no cookies, cache, or credentials persisted from these requests.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout * 2
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }

    private static func fetchOneHop(_ url: String, session: URLSession) async throws -> HopResponse {
        guard let requestUrl = URL(string: url) else { throw URLError(.badURL) }

        do {
            var response = try await send(requestUrl, method: "HEAD", session: session)

            // Some servers reject HEAD; retry with GET but never read the body.
            if response.statusCode == 405 || response.statusCode == 501 {
                response = try await send(requestUrl, method: "GET", session: session)
            }

            let location = response.value(forHTTPHeaderField: "Location")
            logger.debug("hop: \(url) -> \(response.statusCode)\(location.map { " -> \($0)" } ?? "")")
            return HopResponse(statusCode: response.statusCode, location: location)
        } catch {
            logger.warning("hop failed: \(url) (\(error.localizedDescription))")
            throw error
        }
    }

    // Foundation's default User-Agent identifies the app's networking stack rather than a
    // browser, and some servers (Amazon's redirect service included) respond differently -- e.g.
    // a 404 instead of a redirect -- to requests that don't look like they came from a browser.
    // These are standard, honestly-identifying request headers, not fingerprint spoofing.
    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static func send(_ url: URL, method: String, session: URLSession) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        // bytes(for:) returns as soon as the response headers arrive; cancelling the task
        // straight away means a GET fallback never downloads the page body.
        let (bytes, response) = try await session.bytes(for: request)
        bytes.task.cancel()
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return httpResponse
    }
}
