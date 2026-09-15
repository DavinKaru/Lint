# Privacy

Lint's baseline behavior is fully offline: cleaning a shared URL never involves the network at
all. There is one deliberate, narrow exception.

## Short links

Some tracking parameters only appear after a short link redirects to its full destination — the
short link itself carries none. To clean those, Lint needs to know the destination first. When a
shared link's host is exactly one of the domains below, `ShortLinkResolver` follows the redirect
before cleaning.

This table is the single source of truth for which domains Lint resolves — nothing else in this
repo (docs or otherwise) should re-list them. It must stay in sync with
`ShortLinkResolver.KNOWN_SHORT_LINK_HOSTS` in
[`platforms/android/app/src/main/java/com/lint/share/ShortLinkResolver.kt`](platforms/android/app/src/main/java/com/lint/share/ShortLinkResolver.kt),
which is the actual enforcement point.

| Domain | Provider | Status | Notes |
|---|---|---|---|
| `amzn.to`, `amzn.asia`, `a.co` | Amazon | Blocked | Amazon's redirect service returns a `404` with an empty body regardless of headers sent (confirmed on `amzn.asia` and `a.co` from a real device) — most likely bot detection at the TLS/HTTP-protocol level. Lint doesn't attempt to mimic a real browser's network fingerprint to work around this (see rationale below). The code path stays in place in case Amazon's behavior changes; today it just fails safe to the unresolved link. |
| `youtu.be` | YouTube | Confirmed working | Full redirect chain (`youtu.be` → `youtube.com` → `m.youtube.com`) resolves successfully and consistently on a real device, no blocking observed. |
| `t.co` | X/Twitter | Not yet confirmed | Added alongside `youtu.be`; not yet tested on a real device. |
| `fb.watch` | Facebook | Not yet confirmed | Added later for Facebook Watch video shares; not yet tested on a real device. |
| `spoti.fi` | Spotify | Not yet confirmed | Resolves to an `open.spotify.com` link carrying a `si` tracking token; not yet tested on a real device. |
| `vm.tiktok.com`, `vt.tiktok.com` | TikTok | Not yet confirmed | Resolves to a `tiktok.com/@user/video/…` link carrying several share-tracking params (`is_from_webapp`, `sender_device`, `share_app_id`, etc. — see `UrlCleaner.kt`); not yet tested on a real device. |

### How resolution works

- Lint makes a direct, on-device HTTP request from your phone straight to that provider's
  redirect service, asking only for headers (a `HEAD` request, falling back to `GET` without
  reading the body if a server rejects `HEAD`) — no page content is ever downloaded.
- This request goes straight from your device to the provider. No Lint-operated server is
  involved, and none ever will be for this feature (routing it through a Lint server, even just
  for caching or performance, would turn that server into a single point that could see every
  user's links, which defeats the purpose of an otherwise fully on-device tool).
- This is the same request your phone would make anyway the moment you (or whoever you send the
  link to) actually opened it — Lint just makes it slightly earlier, to strip tracking params
  before the link is shared onward.
- If the request times out, fails, or the provider's server responds unexpectedly, Lint gives up
  and passes the original short link through unchanged. It never blocks or crashes the share
  flow.

Lint doesn't attempt to defeat bot detection (e.g. by mimicking a real browser's full network
fingerprint) to force a blocked provider like Amazon to resolve — that would be fragile, an arms
race against the provider's own detection, and closer to bot-detection evasion than to normal
client behavior for a tool like this.

Every other link Lint handles — everything that isn't one of the domains in the table above —
stays fully offline, exactly as described in the main [`README.md`](README.md).
