# Architecture

Lint is structured to support multiple platforms from day one, even though only Android is
actively being built right now.

## Layout

```
/platforms
  /android    <- the real, active project
  /ios        <- placeholder, not started
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
  Android's Gradle project lives entirely inside `/platforms/android`; a future iOS Xcode
  project would live entirely inside `/platforms/ios`, and so on. Nothing platform-specific
  leaks outside its own directory.

- **`/shared`** — anything genuinely platform-agnostic lives here instead of being duplicated
  per platform. The main example today is the tracking-parameter rule catalog
  (`/shared/rules`): rather than hand-maintaining a separate `utm_*`/`fbclid`/`gclid`/etc. list
  per platform, there's one canonical list, and each platform's build consumes it however fits
  its own toolchain (bundled asset, generated source, etc.). `/shared/docs` holds design notes
  that apply across platforms rather than to one specific implementation.

- **Placeholders** (`/platforms/ios`) exist purely so the directory structure doesn't need to
  change shape later — adding a platform means filling in an existing folder, not restructuring
  the repo.
