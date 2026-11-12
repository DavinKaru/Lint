# Privacy

Lint's baseline behavior is fully offline: cleaning a shared URL never involves the network at
all. There is one deliberate, narrow exception.

## Short links

Some tracking parameters only appear after a short link redirects to its full destination — the
short link itself carries none. To clean those, Lint needs to know the destination first. When a
shared link's host is exactly one of the domains below (or, for the few listed share paths, its host and path match that path's pattern), `ShortLinkResolver` follows the redirect
before cleaning.

This table is the single source of truth for which domains Lint resolves — nothing else in this
repo (docs or otherwise) should re-list them. It must stay in sync with
`shortLinkHosts` and `shortLinkPaths` in [`shared/rules/rules.json`](shared/rules/rules.json), which both apps'
code is generated from and is the actual enforcement point. The Status column reflects Android device testing; iOS
hasn't been tested on a real device yet.

| Domain | Provider | Status | Notes |
|---|---|---|---|
| `amzn.to`, `amzn.asia`, `a.co` | Amazon | Blocked | Amazon's redirect service returns a `404` with an empty body regardless of headers sent (confirmed on `amzn.asia` and `a.co` from a real device) — most likely bot detection at the TLS/HTTP-protocol level. Lint doesn't attempt to mimic a real browser's network fingerprint to work around this (see rationale below). The code path stays in place in case Amazon's behavior changes; today it just fails safe to the unresolved link. |
| `youtu.be` | YouTube | Confirmed working | Full redirect chain (`youtu.be` → `youtube.com` → `m.youtube.com`) resolves successfully and consistently on a real device, no blocking observed. |
| `t.co` | X/Twitter | Not yet confirmed | Added alongside `youtu.be`; not yet tested on a real device. |
| `fb.watch` | Facebook | Not yet confirmed | Added later for Facebook Watch video shares; not yet tested on a real device. |
| `spoti.fi` | Spotify | Not yet confirmed | Resolves to an `open.spotify.com` link carrying a `si` tracking token; not yet tested on a real device. |
| `vm.tiktok.com`, `vt.tiktok.com` | TikTok | Not yet confirmed | Resolves to a `tiktok.com/@user/video/…` link carrying several share-tracking params (`is_from_webapp`, `sender_device`, `share_app_id`, etc. — see `UrlCleaner.kt`); not yet tested on a real device. |
| `maps.app.goo.gl` | Google Maps | Not yet confirmed | Google Maps share links. Resolves to a `google.com/maps/…` link carrying `g_st`/`g_ep` share params, which are then stripped. Not yet tested on a real device. |
| `redd.it`, and `reddit.com/r/<sub>/s/<code>` share paths | Reddit | Not yet confirmed | The Reddit app shares `/s/` links on reddit.com itself; only that exact path shape is resolved, never other reddit.com links. Resolves to the full post link carrying `share_id` and `utm_*`. Reddit may block non-browser requests, in which case the link is shared unchanged. Not yet tested on a real device. |
| `facebook.com/share/…` share paths | Facebook | Not yet confirmed | Facebook's newer share links (`/share/p/<code>/`, `/share/r/<code>/`, `/share/<code>/`); only those path shapes are resolved. Not yet tested on a real device. |
| `pin.it` | Pinterest | Not yet confirmed | Resolves to a pin link carrying `invite_code`/`sender`, which identify the sharer and are then stripped. Not yet tested on a real device. |
| `lnkd.in` | LinkedIn | Not yet confirmed | LinkedIn's short links. Not yet tested on a real device. |
| `fb.me` | Facebook | Not yet confirmed | Older Facebook short links. Not yet tested on a real device. |
| `on.soundcloud.com` | SoundCloud | Not yet confirmed | Resolves to a track link carrying the `si` share token, then stripped. Not yet tested on a real device. |
| `ebay.us` | eBay | Not yet confirmed | eBay's share short links. Not yet tested on a real device. |
| `a.aliexpress.com` | AliExpress | Not yet confirmed | AliExpress app share links. Not yet tested on a real device. |
| `flip.it` | Flipboard | Not yet confirmed | Flipboard's short links. Not yet tested on a real device. |
| `link.deezer.com` | Deezer | Not yet confirmed | Deezer's share links. Not yet tested on a real device. |
| `<account>.<dc>.list-manage.com/track/click` | Mailchimp | Not yet confirmed | Newsletter click links. Their `e=` param identifies you as the subscriber, so the link is resolved to its destination instead of being shared as is. Resolving it counts as a click by you in the sender's stats, much like opening it would. Only the `/track/click` path is resolved. Not yet tested on a real device. |

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
- If a redirect lands on a sign-in or consent page (Facebook's login page, Google's cookie
  consent, LinkedIn's sign-in wall, ... listed as `deadEndPages` in
  [`shared/rules/rules.json`](shared/rules/rules.json)), Lint stops there without requesting it:
  - if the page carries the full link it continues to (a consent page's `continue=`, a Facebook
    sign-in page's `next=`) and that isn't another sign-in page, Lint uses that link;
  - otherwise it keeps the link from the step before when that's on the same site as the sign-in
    page (the post or video it was protecting), and the original short link if not;
  - except when that link identifies you (a Mailchimp click link carries your subscriber ID): then
    Lint shares the sign-in page itself, which still leads to the content once signed in.

Lint doesn't attempt to defeat bot detection (e.g. by mimicking a real browser's full network
fingerprint) to force a blocked provider like Amazon to resolve — that would be fragile, an arms
race against the provider's own detection, and closer to bot-detection evasion than to normal
client behavior for a tool like this.

Every other link Lint handles — everything that isn't one of the domains in the table above —
stays fully offline, exactly as described in the main [`README.md`](README.md).
