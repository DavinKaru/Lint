# Notes

## Licensing caveat

The project currently uses a placeholder MIT license for the code (see `LICENSE`).

If we later decide to bundle a GPL- or LGPL-licensed tracking-parameter ruleset directly (e.g. the
rules from [ClearURLs](https://github.com/ClearURLs/Rules), which are LGPL-3.0, or AdGuard's and
uBlock Origin's filters, which are GPL-3.0), that would likely
require relicensing the project (or at least the affected module) under GPL-3.0 or a
GPL-compatible license, since GPL-3.0 is copyleft and would impose that requirement on the
combined work. This has NOT been decided — it's flagged here so it gets a deliberate decision
rather than being silently assumed one way or the other.

Options if that day comes:
- Relicense the whole project GPL-3.0.
- Write our own tracking-parameter ruleset from scratch (clean-room) to avoid the GPL dependency.
- Keep MIT and consume ClearURLs' data (not code) if that's legally distinct enough — needs real
  legal judgment, not an assumption baked in here.

## Research signals (param research)

`shared/research/research.py` (see its README) reads ClearURLs (LGPL-3.0), AdGuard's URL Tracking
filter (GPL-3.0), uBlock Origin's privacy filters (GPL-3.0), Firefox's query stripping list
(MPL-2.0) and the Tranco top list **at run time, as research signals only**. To keep that clear of
the caveat above:

- Nothing from those lists is vendored, committed or copied into `rules.json` or the generated
  code. Downloads go to a temporary or ignored directory (`shared/research/cache/`) and are never
  committed. The test fixtures are hand-written with made-up names.
- The script never writes rules. A lead from the report becomes a rule only after we've seen the
  param in a real shared link, written our own test case for it, and checked the cleaned link
  still works, so each rule rests on our own observation rather than on a list's entry.
- The monthly report (a GitHub issue) names params and sites, not copies of the lists' rules.
