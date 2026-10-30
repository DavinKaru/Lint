# Shared link cases

`link-cases.json` is the test set both platforms are checked against: real shared links (or the
whole text an app shares) and exactly what Lint must turn them into. The Android tests
(`SharedLinkCasesTest.kt`) and the iOS tests (`SharedLinkCasesTests.swift`) each load this file and
assert every case, so a rule change that breaks a case fails on both. It's also how the 1.0 goal of
"cleans most of what people share" is measured (see the [1.0.0 milestone](https://github.com/DavinKaru/Lint/milestone/1)).

## The file

- **`clean`**: share text in, expected text out, run through `cleanFirstUrl`. For links that would
  break if cleaned, or sources Lint deliberately skips, `expected` is the same as `input`.
- **`shortLinks`**: whether a URL's host is one Lint resolves before cleaning
  (`isKnownShortLink`). Lookalike and full-length links belong here too, as `known: false`.

Each case records its `source` (the app or site), `category` (the same categories as the
[Link support board](https://github.com/users/DavinKaru/projects/1)), `verified` (the date it was
last checked against a real share) and optional `notes`.

## Adding a case

1. Share a real link from the app and copy exactly what it shares.
2. **Replace anything personal** with a placeholder that keeps the shape: names, plate numbers,
   addresses, and per-share tokens or IDs (`sg`, `suid`, `si`, trip codes...). This file is public.
3. Add the case with today's date as `verified`, then run the tests on both platforms. CI runs
   them on every PR that touches `shared/`.

## Coverage

```
python3 shared/tests/coverage.py
```

prints how many cases each category and source has, so gaps are easy to spot.
