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

- **Until `/shared/rules` exists**, the tracking-parameter lists and short-link domains are
  hand-copied between `UrlCleaner.kt`/`ShortLinkResolver.kt` (Android) and
  `UrlCleaner.swift`/`ShortLinkResolver.swift` (iOS). Any change to one must be made to the
  other in the same PR; each platform's tests are ports of each other, so keep those in step too.

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
