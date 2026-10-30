# Architecture

Lint is structured to support multiple platforms from day one: Android and iOS today.

## Layout

```
/platforms
  /android    <- Gradle project (Kotlin)
  /ios        <- Xcode project (Swift)
/shared
  /rules      <- tracking-parameter rule catalog, shared across platforms
  /docs       <- cross-platform architecture/design notes
ARCHITECTURE.md
README.md
LICENSE
.gitignore
```

## Intent

- **`/platforms/<os>`** — each platform is a self-contained, independently buildable project.
  Android's Gradle project lives entirely inside `/platforms/android`; the iOS Xcode project
  lives entirely inside `/platforms/ios`, and so on. Nothing platform-specific
  leaks outside its own directory.

- **`/shared`** — anything genuinely platform-agnostic lives here instead of being duplicated
  per platform. The main example today is the tracking-parameter rule catalog
  (`/shared/rules`): rather than hand-maintaining a separate `utm_*`/`fbclid`/`gclid`/etc. list
  per platform, there's one canonical list, and each platform's build consumes it however fits
  its own toolchain (bundled asset, generated source, etc.). `/shared/docs` holds design notes
  that apply across platforms rather than to one specific implementation.

- **`/shared/rules/rules.json`** is the single source of truth for the tracking params, prefixes,
  site-specific params and short-link domains on every platform. `shared/rules/generate.py` turns
  it into `GeneratedRules.kt` (Android) and `GeneratedRules.swift` (iOS), which are committed, and
  CI checks they match. Change rules there, never in platform code (see `shared/rules/README.md`).

- **`/shared/tests/link-cases.json`** is the test set of real shared links that both platforms'
  tests load and check, so a rule change that breaks a case fails on both. Add a case for every
  source Lint supports or deliberately skips (see `shared/tests/README.md`).

## Releases

Each platform is versioned and released independently, even for releases intended to ship the
same feature set "in tandem" — Android (`versionCode`/`versionName`) and iOS
(`CFBundleVersion`/`CFBundleShortVersionString`) are separate store-facing mechanisms with their
own review/rollout timelines, and forcing a single shared release moment across both is fragile
(e.g. an App Store rejection shouldn't block or get entangled with an Android release).

Git tags and GitHub Releases are scoped per platform with a prefix: `android-v0.1.0`,
`ios-v0.1.0`, etc. The semver number itself is still chosen to reflect feature parity where it
exists (e.g. both platforms' `v0.1.0` ship the same feature set), but each platform's tag,
release notes, and rollout are independent — never a single bare `v0.1.0` tag covering both.

The existing `v0.1.0` tag predates this convention (it was Android's only release, before iOS
was a real consideration) and is left as-is rather than retroactively renamed.
