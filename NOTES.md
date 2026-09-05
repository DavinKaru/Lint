# Notes

## Licensing caveat

The project currently uses a placeholder MIT license for the code (see `LICENSE`).

If we later decide to bundle a GPL-3.0-licensed tracking-parameter ruleset directly (e.g. the
rules from [ClearURLs](https://github.com/ClearURLs/Rules), which is GPL-3.0), that would likely
require relicensing the project (or at least the affected module) under GPL-3.0 or a
GPL-compatible license, since GPL-3.0 is copyleft and would impose that requirement on the
combined work. This has NOT been decided — it's flagged here so it gets a deliberate decision
rather than being silently assumed one way or the other.

Options if that day comes:
- Relicense the whole project GPL-3.0.
- Write our own tracking-parameter ruleset from scratch (clean-room) to avoid the GPL dependency.
- Keep MIT and consume ClearURLs' data (not code) if that's legally distinct enough — needs real
  legal judgment, not an assumption baked in here.
