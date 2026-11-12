# Rules catalog

`rules.json` is the **single source of truth** for what Lint strips and which short links it
resolves, on every platform:

| Section | What it holds |
|---|---|
| `trackingPrefixes` | Param prefixes stripped on every site (`utm_`, `mtm_`, ...) |
| `trackingParams` | Exact param names stripped on every site (`fbclid`, `gclid`, ...) |
| `siteParams` | Params only stripped on specific sites, because their names are generic (`si` on YouTube/Spotify, `aff`/`sg` on Eventbrite). A site matches its subdomains too; a site ending in `.*` matches that name on any country domain (`eventbrite.*`). An entry with `paths` only applies on pages whose path matches one of them (see **Path patterns**): Amazon's `keywords` is the search that found a product on `/dp/<asin>` pages, but the query itself on `/s?keywords=` search links. Each site has at most one entry without `paths`. |
| `shortLinkHosts` | Hosts whose links are resolved (redirects followed) before cleaning. The table in `PRIVACY.md` tracks each one's status. |
| `shortLinkPaths` | Short links that live on a path of an ordinary site (`reddit.com/r/<sub>/s/<code>`), matched with **Path patterns**. Resolved like `shortLinkHosts`; also listed in `PRIVACY.md`. |
| `deadEndPages` | Sign-in and consent pages (**Path patterns**). When resolving a short link redirects to one, Lint stops and keeps the link from the step before, unless the page carries the full link it continues to (a `redirectWrappers` entry), which is used instead. |
| `redirectWrappers` | Redirect links that carry the real link in a query param (`google.com/url?q=`, `l.facebook.com/l.php?u=`, Outlook Safe Links, ...). Lint unwraps them **offline**, before anything else. `paths` match exactly, or as a prefix when they end in `*`; the first `params` value that decodes to a valid http(s) link wins. Values are percent-encoded, unless `base64Prefix` is set: then the value must be that prefix followed by unpadded base64url (Bing's `u=a1aHR0c...`). Set `targetSites` when the real service only continues to its own sites (Google's consent page, Facebook's sign-in page): any other target leaves the link alone, so Lint never sends a link somewhere the original wouldn't go. |
| `pathWrappers` | Redirect links that carry the real link in their path (`google.com/amp/s/<host>/<path>`). |
| `neverStrip` | Params that must never be stripped globally because they identify the content somewhere (`cid` on Google Maps, `eid` on Google Calendar). |

Every entry has a `source` (or `provider`) and optional `notes` explaining why it's there; they're
carried into the generated code as comments.

## Path patterns

`siteParams` `paths`, `shortLinkPaths` and `deadEndPages` match the whole path, one `/`-separated
segment at a time (leading and trailing slashes are ignored, and the path is compared still
percent-encoded):

- a name matches that segment exactly (case-sensitive);
- `*` matches any one non-empty segment;
- a final `**` matches the rest of the path, including nothing.

So `/dp/*/**` matches `/dp/B0ABCDEF12` and `/dp/B0ABCDEF12/ref=sr_1_3`, but not `/dp/` or
`/s`, and `/**` matches every path. (`redirectWrappers` paths are simpler: exact, or a prefix
when they end in `*`.)

Patterns only hold characters a URL path keeps unencoded (no `?`, `#`, `%` or spaces), since
anything else could never match. A `siteParams` path needs at least one named segment: `/*/**`
would also cover search pages like Amazon's `/s`, where the same param is the search itself.

## Changing the rules

1. Edit `rules.json`. Prefer a `siteParams` entry over a global one unless the name can't mean
   anything else: breaking a link is worse than leaving a tracker in.
2. Run `python3 shared/rules/generate.py`. It checks the catalog (no duplicates, nothing from
   `neverStrip` stripped globally, prefixes ending in `_`, lowercase domains) and rewrites:
   - `platforms/android/app/src/main/java/com/lint/share/GeneratedRules.kt`
   - `platforms/ios/LintCore/Sources/LintCore/GeneratedRules.swift`
3. Add a case for the source to `shared/tests/link-cases.json` (see `shared/tests/README.md`).
4. Commit `rules.json` and both generated files together. CI fails if they don't match.

The generated files are committed so neither the Gradle nor the Xcode build needs Python.
