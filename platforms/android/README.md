# Lint — Android
The current prototype is a share-sheet-only app with no UI and no launcher icon (though I'll get to that soon). It's made to exist purely as an entry in the Android share sheet.

- **Package:** `com.lint.share`
- **minSdk:** 24 · **compileSdk/targetSdk:** 36
- **Dependencies:** none beyond the Android SDK (no AndroidX, no third-party libraries)

## How it works
`ShareActivity` is a trampoline: it has no layout, uses a translucent theme (`Theme.Translucent.NoTitleBar` — not `Theme.NoDisplay`, since that theme requires `finish()` before `onResume()` returns, which the Amazon resolution path below can't guarantee), and is registered only for `ACTION_SEND` / `text/plain` (deliberately no `MAIN`/`LAUNCHER` intent-filter, so it never appears as an app icon). On receiving a share, it hands the shared text to `UrlCleaner` which is a standalone, unit-testable object that finds the first `http(s)` URL, strips known tracking query parameters (the `utm_*`/`mtm_*` prefixes plus an explicit list covering Google, Meta, Amazon, Reddit, LinkedIn, and other platforms tracked in `UrlCleaner.kt`), and preserves everything else (unrecognised params, the fragment). The cleaned text is then re-shared via `Intent.createChooser()` and the activity finishes.

For known short links (`amzn.to`/`amzn.asia`/`a.co`, `youtu.be`, `t.co`) specifically, `ShortLinkResolver` first follows the redirect (a direct, headers-only, on-device request to that provider — see [`/PRIVACY.md`](../../PRIVACY.md)) to find the full destination URL, since some tracking params only appear after that redirect. This resolve step runs on a background thread with a ~3s total budget; any failure or timeout falls back to the original short link unchanged. Every other link skips this entirely and stays fully synchronous/offline, exactly as before.

**Known limitation — Amazon:** as of this writing, Amazon's servers block this resolution request
outright (a `404` with an empty body, confirmed on `amzn.asia` and `a.co` from real devices,
likely TLS/protocol-level bot detection rather than anything about the request's headers/content).
The code stays in place — it fails safe, falling back to the unresolved short link exactly like
any other failure — but it currently doesn't succeed in practice for Amazon.

**`youtu.be` confirmed working** on a real device: the full redirect chain (`youtu.be` →
`youtube.com` → `m.youtube.com`) resolves successfully, consistently, with no blocking. `t.co`
was added at the same time but not yet tested — update this note once known. See `PRIVACY.md`
for the full note.

## Building and testing
```
cd platforms/android
./gradlew assembleDebug   # -> app/build/outputs/apk/debug/app-debug.apk
./gradlew test            # runs UrlCleanerTest and ShortLinkResolverTest
```

## Installing
```
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Since there's no launcher icon, you won't see it in the app drawer, but it shows up as an option in the OS share sheet from any app (browser, Messages, etc.) once installed.

## Status
Working prototype, released as v0.1.0 (debug-signed APK — see GitHub Releases). Not yet using a
proper release signing key.