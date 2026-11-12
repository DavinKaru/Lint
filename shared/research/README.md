# Param research

`research.py` looks for tracking params and share sources Lint may be missing, using **public lists
only**. It never uses anything from Lint's users (Lint has no telemetry), and it **never adds rules**:
it writes a report of leads, and every lead goes through the normal routine in
[`shared/rules/README.md`](../rules/README.md) before it reaches `rules.json`:

1. Share a real link from the app.
2. Add a test case to `shared/tests/link-cases.json`.
3. Check the cleaned link still opens the same thing.

## What it reads

| Source | Used for | Licence |
|---|---|---|
| [ClearURLs rules](https://github.com/ClearURLs/Rules) (`data.minify.json`) | Params per site, referral (affiliate) params, redirect links | LGPL-3.0 |
| [AdGuard URL Tracking filter](https://github.com/AdguardTeam/AdguardFilters) (filter 17) | `$removeparam` rules | GPL-3.0 |
| [uBlock Origin privacy filters](https://github.com/uBlockOrigin/uAssets) (`privacy.txt`) | `$removeparam` and `$urlskip` rules | GPL-3.0 |
| [Firefox query stripping](https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/query-stripping/records) | Params Firefox strips everywhere | MPL-2.0 |
| [Tranco top 1M](https://tranco-list.eu) | Ranking sites by popularity | Free to use, cite Tranco |

Brave's query filter isn't included: it lives in Brave's C++ source, not in a data file with a
stable URL.

All of it is downloaded at run time and thrown away afterwards. **Don't commit any downloaded list**
(see the licence note in [`NOTES.md`](../../NOTES.md)). The fixtures in `fixtures/` are hand-written
for the tests, with made-up names, and not taken from any list.

## What it reports

It compares the lists with `shared/rules/rules.json`, using the same site matching as
`UrlCleaner.hostMatches` (so `amazon.*` covers `amazon.co.uk`), and ranks leads by how many lists
agree, then whether the site is on the 1.0 target list (`shared/tests/targets.json`), then Tranco
rank:

- Params several lists strip on every site that Lint doesn't.
- Params several lists strip on a site that Lint doesn't strip there.
- Params one list strips on a target site.
- Popular sites several lists have rules for that aren't targets yet (possible new share sources).
- Redirect links the lists unwrap that Lint doesn't (compared by site, not path).
- Params Lint keeps on purpose that lists strip: `neverStrip`, params a link case keeps in its
  expected output (content IDs, variant selectors), and affiliate IDs (#28). For information only.

Plain param names are compared. Simple regexes (`(?:%3F)?name`, `name[a-z]*`, `/^name_/`) are read as
a name or a prefix; anything more complex is counted in the Sources table and skipped. Names are
compared ignoring case. The report is capped to fit a GitHub issue (65,536 characters).

## Running it

```
python3 shared/research/research.py                  # download the lists, print the report
python3 shared/research/research.py --out report.md  # write it to a file
python3 shared/research/research.py --save DIR       # keep the downloads (outside the repo, or in
                                                     #   shared/research/cache/, which is ignored)
python3 shared/research/research.py --offline DIR    # reuse them: clearurls.json, adguard.txt,
                                                     #   ublock.txt, firefox.json, tranco.csv.zip
```

`--min-lists` (default 2) sets how many lists must agree, `--limit` (default 60) the rows per table.
A source that fails to download (each is tried 3 times, then its mirror) is listed as failed in the
report and skipped. Downloads cut short are caught by the list's checksum or a missing final
newline. The script exits with 2 only if no tracking list could be loaded.

Tests (no network):

```
python3 -m unittest discover -s shared/research
```

## The monthly issue

[`.github/workflows/research.yml`](../../.github/workflows/research.yml) runs the script on the 1st
of each month (and on demand from the Actions tab) and puts the report in one issue titled
**Param research report**, labelled `research`: it updates the open one, reopens the last closed one,
or creates it. It uses the built-in `GITHUB_TOKEN` with `issues: write` only.

The [Link support board](https://github.com/users/DavinKaru/projects/1) is a Projects v2 board, which
that token can't write to, so cards are added by hand from the report.
