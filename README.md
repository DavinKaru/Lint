# Lint
A share-sheet-only mobile utility that strips tracking parameters from URLs when you share them.

## The problem
Links shared from social apps, search engines, and news sites are routinely decorated with
tracking parameters such as `utm_source`, `utm_medium`, `fbclid`, `gclid`, `igshid`, and many more.
These parameters do nothing for the person receiving the link; they exist to let the originating
platform (and often several ad-tech intermediaries) follow you across sites and correlate your
activity. Every time you share a link, you're forwarding that tracking to whoever you send it to.

## How it works
Lint has no visible UI beyond the OS share sheet:
1. You tap "Share" on a link in any app.
2. You pick Lint from the share sheet.
3. Lint strips known tracking parameters from the URL.
4. The OS share sheet reopens with the cleaned link, ready to send wherever you originally intended.

There are no accounts, no settings screens, and no network calls, everything happens on-device,
and nothing about the link or your activity ever leaves the phone.

## Status
Android prototype in progress. iOS support is planned but not yet started.

## Repo layout
The project is organized to support multiple platforms from the start — see `ARCHITECTURE.md`
for the full explanation. In short: each platform lives in its own self-contained directory
under `/platforms`, and anything genuinely shared across platforms (like the tracking-parameter
rule catalog) lives under `/shared`.

## Contributing
Contribution guidelines will go here once the project is far enough along to support outside
contributions. In the meantime, feel free to open an issue with ideas or bug reports.

## License
MIT (placeholder — see `LICENSE`; not yet finalized). See `NOTES.md` for a licensing caveat
around potential future use of GPL-3.0 tracking-parameter rulesets.
