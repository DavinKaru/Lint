# Tracking-parameter rule catalog

This directory will hold the shared, platform-agnostic list of tracking parameters to strip
(e.g. a JSON file enumerating `utm_*`, `fbclid`, `gclid`, `igshid`, and similar). Each platform's
build consumes this file however fits its toolchain (bundled asset, generated code, etc.) rather
than maintaining its own separate copy.

No catalog file exists yet — this will be added once the Android prototype needs one.
