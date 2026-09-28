# Lint — iOS
The iOS version of Lint is a share extension with the same feature set as Android: it strips the same tracking parameters, and resolves the same short links first. It's made to exist purely as an entry in the iOS share sheet.

- **Bundle IDs:** `com.lint.share` (app) · `com.lint.share.ShareExtension` (share extension)
- **Minimum iOS:** 17.0 (Liquid Glass on iOS 26+, the standard system material before that)
- **Dependencies:** none beyond the iOS SDK

## How it works
iOS doesn't allow a share extension on its own, so there are two targets:

- **`Lint`** (the app) is a single screen explaining how to use the share extension. It has no accounts and no settings.
- **`LintShare`** (the share extension) does the actual work. It's offered for shares containing one web link or some text (see `LintShare/Info.plist`). `ShareViewController` reads the shared URL (or text), hands it to `UrlCleaner`, copies the cleaned result to the clipboard, and shows a small "Link cleaned and copied" card for about a second before closing itself (tap to close it sooner). A shared URL is copied as a URL, so it pastes as a proper link; shared text is copied as text with only its first URL cleaned.

This is the one deliberate difference from Android, which re-shares the cleaned link through a new share sheet. iOS always presents a share extension as a sheet of its own, so re-sharing from inside it leaves an empty sheet behind the new share sheet, and Lint shows up in its own list (excluding it doesn't work for third-party extensions). Copying avoids both and is the usual pattern for iOS link tools.

The cleaning and resolving logic lives in `LintCore`, a local Swift package that the share extension links. It's a direct port of Android's `UrlCleaner.kt` and `ShortLinkResolver.kt`: the same parameter lists (including the params that are only stripped on their own sites), the same short-link domains, the same 5-hop limit, and the same fail-safe behavior. Any change to one platform's lists must be made to the other's too (see `ARCHITECTURE.md`).

For known short links, `ShortLinkResolver` first follows the redirect (a direct, headers-only, on-device request to that provider) to find the full destination URL. Requests use an ephemeral `URLSession` (no cookies, cache or credentials kept) that refuses automatic redirects, so each hop is inspected and followed by hand. The whole resolution has a hard 3s cap; any failure or timeout falls back to the original short link unchanged.

While that runs, the same card (`StatusCardView`) shows a spinner and "Tumbling out the tracking…" before switching to the confirmation. It uses Liquid Glass (`glassEffect`) on iOS 26 and `.regularMaterial` on earlier versions.

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
New and not yet tested on a real device. Tested in the iOS 26 simulator: offline cleaning and `youtu.be` resolution both work end to end from Safari. The version (`MARKETING_VERSION`, set once at the project level) is 0.3.0 to match the Android feature set it ports; there's no iOS release yet.
