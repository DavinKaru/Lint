# Rules catalog

`rules.json` is the **single source of truth** for what Lint strips and which short links it
resolves, on every platform:

| Section | What it holds |
|---|---|
| `trackingPrefixes` | Param prefixes stripped on every site (`utm_`, `mtm_`, ...) |
| `trackingParams` | Exact param names stripped on every site (`fbclid`, `gclid`, ...) |
| `siteParams` | Params only stripped on specific sites, because their names are generic (`si` on YouTube/Spotify, `aff`/`sg` on Eventbrite). A site matches its subdomains too; a site ending in `.*` matches that name on any country domain (`eventbrite.*`). |
| `shortLinkHosts` | Hosts whose links are resolved (redirects followed) before cleaning. The table in `PRIVACY.md` tracks each one's status. |
| `neverStrip` | Params that must never be stripped globally because they identify the content somewhere (`cid` on Google Maps, `eid` on Google Calendar). |

Every entry has a `source` (or `provider`) and optional `notes` explaining why it's there; they're
carried into the generated code as comments.

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
