# Lint
[![Android release](https://img.shields.io/github/v/tag/DavinKaru/Lint?filter=android-*&label=android)](https://github.com/DavinKaru/Lint/releases)

A share-sheet-only mobile utility that strips tracking parameters from URLs when you share them.

## The problem
Links shared from social apps, search engines, and news sites are routinely decorated with tracking parameters such as `utm_source`, `utm_medium`, `fbclid`, `gclid`, `igshid`, and many more. These parameters do nothing for the person receiving the link; they exist to let the originating platform (and often several ad-tech intermediaries) follow you across sites and correlate your activity. Every time you share a link, you're forwarding that tracking to whoever you send it to.

## How it works
Lint has no visible UI beyond the OS share sheet:
1. You tap "Share" on a link in any app.
2. You pick Lint from the share sheet.
3. Lint strips known tracking parameters from the URL.
4. The OS share sheet reopens with the cleaned link, ready to send wherever you originally intended.

The one exception: for known short links, Lint briefly shows a small loading screen while it resolves the short link's real destination on-device — everything else stays instant with zero UI at all. See [`PRIVACY.md`](PRIVACY.md) for exactly which domains, what that involves, and why it's safe.

There are no accounts and no settings screens. Almost everything happens fully offline, and on-device.

## Status
Android has a working prototype (see the [release badge above](https://github.com/DavinKaru/Lint/releases) for the current version, and [`platforms/android/README.md`](platforms/android/README.md) for details on how it works, building, and installing).

iOS support is planned but not yet started.

## Repo layout
The project is organised to support multiple platforms from the start (see `ARCHITECTURE.md` for the full explanation). In short: each platform lives in its own self-contained directory under `/platforms`, and anything genuinely shared across platforms (like the tracking-parameter rule catalog) lives under `/shared`.

## Contributing
Contribution guidelines will go here once the project is far enough along to support outside contributions. In the meantime, feel free to open an issue with ideas or bug reports.

## License
MIT (placeholder — see `LICENSE`; not yet finalised). See `NOTES.md` for a licensing caveat around potential future use of GPL-3.0 tracking-parameter rulesets.
