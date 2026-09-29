# Lint — iOS
The iOS version of Lint is a share extension with the same feature set as Android: it strips the same tracking parameters, and resolves the same short links first. It's made to exist purely as an entry in the iOS share sheet.

- **Bundle IDs:** `com.lint.share` (app) · `com.lint.share.ShareExtension` (share extension)
- **Minimum iOS:** 17.0 (Liquid Glass on iOS 26+, the standard system material before that)
- **Dependencies:** none beyond the iOS SDK

## How it works
iOS doesn't allow a share extension on its own, so there are two targets:

- **`Lint`** (the app) is a single screen explaining how to use the share extension. It has no accounts and no settings.
- **`LintShare`** (the share extension) does the actual work. It's offered for shares containing one web link or some text (see `LintShare/Info.plist`). `ShareViewController` reads the shared URL (or text), hands it to `UrlCleaner`, and re-opens the share sheet (`UIActivityViewController`) with the cleaned result, the same as Android. A shared URL is re-shared as a URL, so the next app still shows a link preview; shared text is re-shared as text with only its first URL cleaned.

Two iOS limitations, both from how iOS handles share extensions:
- iOS always presents a share extension inside a system sheet, so that sheet sits behind the re-opened share sheet. Rather than leave it empty, a small "Link cleaned" card fills it. (An action extension asking for full-screen presentation was tried: it avoids Lint's own sheet, but iOS keeps the source app's share sheet open behind it instead, and it's harder to find in the share sheet.)
- Lint lists itself in the share sheet it re-opens. Android excludes itself (`EXTRA_EXCLUDE_COMPONENTS`); iOS has no equivalent for third-party extensions, and marking the item so Lint's activation rule refuses it also made other apps (e.g. Reminders) refuse it.

The cleaning and resolving logic lives in `LintCore`, a local Swift package that the share extension links. It's a direct port of Android's `UrlCleaner.kt` and `ShortLinkResolver.kt`: the same parameter lists (including the params that are only stripped on their own sites), the same short-link domains, the same 5-hop limit, and the same fail-safe behavior. Any change to one platform's lists must be made to the other's too (see `ARCHITECTURE.md`).

For known short links, `ShortLinkResolver` first follows the redirect (a direct, headers-only, on-device request to that provider) to find the full destination URL. Requests use an ephemeral `URLSession` (no cookies, cache or credentials kept) that refuses automatic redirects, so each hop is inspected and followed by hand. Like Android, resolution has a ~3s total budget checked before each hop; on any failure or timeout the chain stops at the furthest URL it reached (the original short link if the first hop fails).

While that runs, the same card (`StatusCardView`) shows a spinner and "Tumbling out the tracking…" before switching to "Link cleaned". It uses Liquid Glass (`glassEffect`) on iOS 26 and `.regularMaterial` on earlier versions.

See [`PRIVACY.md`](../../PRIVACY.md) for the full list of resolved domains and why this is the one exception to Lint being fully offline.

## Building and testing
Open `Lint.xcodeproj` in Xcode 26 or later, set your team under **Signing & Capabilities** for both the `Lint` and `LintShare` targets, then run the `Lint` scheme on a device or simulator.

The `LintCore` tests run on your Mac, no simulator needed:
```
cd platforms/ios/LintCore
swift test
```

To try the share extension in the simulator, run the `LintShare` scheme and pick Safari (or any other app) when Xcode asks which app to run, then share a link from it.

## Status
New and not yet tested on a real device. Tested in the iOS 26 simulator: offline cleaning, `youtu.be` resolution and re-sharing all work end to end from Safari. The version (`MARKETING_VERSION`, set once at the project level) is 0.3.0 to match the Android feature set it ports; there's no iOS release yet.
