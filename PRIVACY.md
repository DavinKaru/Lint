# Privacy

Lint's baseline behavior is fully offline: cleaning a shared URL never involves the network at
all. There is one deliberate, narrow exception.

## Short links (`amzn.to`, `amzn.asia`, `a.co`, `youtu.be`, `t.co`)

Some tracking parameters only appear after a short link redirects to its full destination — the
short link itself carries none. To clean those, Lint needs to know the destination first. When a
shared link's host is exactly one of the domains above:

- Lint makes a direct, on-device HTTP request from your phone straight to that provider's
  redirect service, asking only for headers (a `HEAD` request, falling back to `GET` without
  reading the body if a server rejects `HEAD`) — no page content is ever downloaded.
- This request goes straight from your device to the provider (Amazon, YouTube, or X/Twitter,
  depending on the domain). No Lint-operated server is involved, and none ever will be for this
  feature (routing it through a Lint server, even just for caching or performance, would turn
  that server into a single point that could see every user's links, which defeats the purpose
  of an otherwise fully on-device tool).
- This is the same request your phone would make anyway the moment you (or whoever you send the
  link to) actually opened it — Lint just makes it slightly earlier, to strip tracking params
  before the link is shared onward.
- If the request times out, fails, or the provider's server responds unexpectedly, Lint gives up
  and passes the original short link through unchanged. It never blocks or crashes the share
  flow.

**Known limitation — Amazon specifically:** Amazon's servers currently appear to block this kind
of request outright (a `404` with an empty body, confirmed on `amzn.asia` and `a.co` from a real
device on a real network) regardless of the headers sent — most likely bot-detection based on
TLS/HTTP-protocol-level fingerprinting rather than anything in the request content itself. Lint
doesn't attempt to work around this by mimicking a real browser's network fingerprint; that would
be fragile, an arms race against Amazon's own detection, and closer to bot-detection evasion than
to normal client behavior for a tool like this. The practical result today: Amazon short links
safely fall through unresolved (and therefore unstripped of tracking params), exactly like any
other resolution failure. That code path stays in place in case Amazon's behavior changes.

**`youtu.be` confirmed working:** unlike Amazon, YouTube's redirect chain (`youtu.be` →
`youtube.com` → `m.youtube.com`) resolves successfully with this same plain, headers-only
request — no blocking observed. `t.co` was added at the same time but not yet confirmed either
way — see the main [`README.md`](README.md) for current status.

Every other link Lint handles — everything that isn't one of the domains above — stays fully
offline, exactly as described in the main [`README.md`](README.md).
