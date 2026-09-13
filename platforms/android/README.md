# Lint — Android
The current prototype is a share-sheet-only app with no UI and no launcher icon (though I'll get to that soon). It's made to exist purely as an entry in the Android share sheet.

- **Package:** `com.lint.share`
- **minSdk:** 24 · **compileSdk/targetSdk:** 36
- **Dependencies:** none beyond the Android SDK (no AndroidX, no third-party libraries)

## How it works
`ShareActivity` is a trampoline: it has no layout, uses a translucent theme (`Theme.Translucent.NoTitleBar` — not `Theme.NoDisplay`, since that theme requires `finish()` before `onResume()` returns, which the short-link resolution path below can't guarantee — see `PRIVACY.md` for the Amazon-specific case), and is registered only for `ACTION_SEND` / `text/plain` (deliberately no `MAIN`/`LAUNCHER` intent-filter, so it never appears as an app icon). On receiving a share, it hands the shared text to `UrlCleaner` which is a standalone, unit-testable object that finds the first `http(s)` URL, strips known tracking query parameters (the `utm_*`/`mtm_*` prefixes plus an explicit list covering Google, Meta, Amazon, Reddit, LinkedIn, and other platforms tracked in `UrlCleaner.kt`), and preserves everything else (unrecognised params, the fragment). The cleaned text is then re-shared via `Intent.createChooser()` and the activity finishes.

For known short links specifically, `ShortLinkResolver` first follows the redirect (a direct, headers-only, on-device request to that provider) to find the full destination URL, since some tracking params only appear after that redirect. This resolve step runs on a background thread with a ~3s total budget; any failure or timeout falls back to the original short link unchanged. Every other link skips this entirely and stays fully synchronous/offline, exactly as before.

Since that resolve step involves a short network wait, `ShareActivity` shows a small loading view (`res/layout/activity_resolving.xml`, a spinner and text) only for that path, so the user isn't left wondering if anything's happening. The instant offline path shows nothing at all, same as before.

See [`PRIVACY.md`](../../PRIVACY.md) for the full list of resolved domains, their per-domain confirmed/blocked status, and why this is the one exception to Lint being fully offline.

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
Working prototype (debug-signed APK — see [GitHub Releases](https://github.com/DavinKaru/Lint/releases) for the current version). Not yet using a
proper release signing key.