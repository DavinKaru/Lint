# Privacy
Lint's baseline behavior is fully offline: cleaning a shared URL never involves the network at all. There is one deliberate, narrow exception.

## Amazon short links (`amzn.to`, `amzn.asia`, `a.co`)
Amazon's short links don't carry any tracking parameters themselves, and only appear once the short link redirects to the full product URL. To clean them, Lint needs to know that destination first. When a shared link's host is exactly `amzn.to`, `amzn.asia`, or `a.co`:
- Lint makes a direct, on-device HTTP request from your phone straight to Amazon's redirect service, asking only for headers (a `HEAD` request, falling back to `GET` without reading the body if a server rejects `HEAD`) — no page content is ever downloaded.
- This request goes straight from your device to Amazon. No Lint-operated server is involved, and none ever will be for this feature (routing it through a Lint server, even just for caching or performance, would turn that server into a single point that could see every user's Amazon links, which defeats the purpose of an otherwise fully on-device tool).
- This is the same request your phone would make anyway the moment you (or whoever you send the link to) actually opened it, Lint just makes it slightly earlier, to strip tracking params before the link is shared onward.
- If the request times out, fails, or Amazon's server responds unexpectedly, Lint gives up and passes the original short link through unchanged. It never blocks or crashes the share flow.

At this stage, every other link Lint handles, everything that isn't one of those three domains, stays fully
offline, exactly as described in the main [`README.md`](README.md).
