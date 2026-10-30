#!/usr/bin/env python3
"""Generates each platform's rule code from shared/rules/rules.json.

    python3 shared/rules/generate.py          # rewrite the generated files
    python3 shared/rules/generate.py --check  # exit 1 if they're out of date (used by CI)

rules.json is the only place rules are written. The generated Kotlin and Swift files are
committed, so neither build needs this script, and CI checks they match the catalog.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / "shared/rules/rules.json"
KOTLIN = ROOT / "platforms/android/app/src/main/java/com/lint/share/GeneratedRules.kt"
SWIFT = ROOT / "platforms/ios/LintCore/Sources/LintCore/GeneratedRules.swift"

HEADER = "Generated from shared/rules/rules.json by shared/rules/generate.py. Don't edit by hand."
SITE_KEY = re.compile(r"^[a-z0-9-]+(\.[a-z0-9-]+)*(\.\*)?$")
HOST = re.compile(r"^[a-z0-9-]+(\.[a-z0-9-]+)+$")


def fail(message: str) -> None:
    sys.exit(f"rules.json: {message}")


def validate(rules: dict) -> None:
    """Catches the mistakes that would silently break links or drift."""
    params = [p for group in rules["trackingParams"] for p in group["params"]]
    prefixes = [p for group in rules["trackingPrefixes"] for p in group["prefixes"]]
    hosts = [h for group in rules["shortLinkHosts"] for h in group["hosts"]]
    sites = [s for group in rules["siteParams"] for s in group["sites"]]

    for name, values in (("trackingParams", params), ("trackingPrefixes", prefixes),
                         ("shortLinkHosts", hosts), ("siteParams sites", sites)):
        duplicates = sorted({v for v in values if values.count(v) > 1})
        if duplicates:
            fail(f"duplicate {name}: {', '.join(duplicates)}")

    never = {p for group in rules.get("neverStrip", []) for p in group["params"]}
    for param in params:
        if param in never:
            fail(f'"{param}" is in neverStrip, so it can\'t be a global tracking param')
        if any(param.startswith(prefix) for prefix in prefixes):
            fail(f'"{param}" is already covered by a tracking prefix')
    for prefix in prefixes:
        if not prefix.endswith("_"):
            fail(f'prefix "{prefix}" should end with "_" so it can\'t swallow ordinary names')
    for site in sites:
        if not SITE_KEY.match(site):
            fail(f'site "{site}" should be a lowercase domain, optionally ending in ".*"')
    for host in hosts:
        if not HOST.match(host):
            fail(f'short-link host "{host}" should be a lowercase domain')


def comment_lines(group: dict, prefix: str) -> list[str]:
    text = group["source"] if "source" in group else group["provider"]
    lines = [f"{prefix}{text}"]
    if group.get("notes"):
        lines.append(f"{prefix}  {group['notes']}")
    return lines


def quoted(values: list[str]) -> str:
    return ", ".join(json.dumps(v) for v in values)


def kotlin(rules: dict) -> str:
    out = [f"// {HEADER}", "", "package com.lint.share", "", "internal object GeneratedRules {", ""]

    out.append("    /** Params starting with any of these are stripped on every site. */")
    out.append("    val TRACKING_PREFIXES: List<String> = listOf(")
    for group in rules["trackingPrefixes"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['prefixes'])},")
    out += ["    )", ""]

    out.append("    /** Params stripped on every site. */")
    out.append("    val TRACKING_PARAMS: Set<String> = setOf(")
    for group in rules["trackingParams"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['params'])},")
    out += ["    )", ""]

    out.append("    /**")
    out.append("     * Params only stripped on specific sites, because their names are generic enough to mean")
    out.append("     * something real elsewhere. Keys match the host and its subdomains; a key ending in \".*\"")
    out.append("     * matches that name on any country domain (see UrlCleaner.hostMatches).")
    out.append("     */")
    out.append("    val SITE_PARAMS: Map<String, Set<String>> = mapOf(")
    for group in rules["siteParams"]:
        out += comment_lines(group, "        // ")
        for site in group["sites"]:
            out.append(f"        {json.dumps(site)} to setOf({quoted(group['params'])}),")
    out += ["    )", ""]

    out.append("    /** Hosts whose links are resolved (redirects followed) before cleaning. */")
    out.append("    val SHORT_LINK_HOSTS: Set<String> = setOf(")
    for group in rules["shortLinkHosts"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['hosts'])},")
    out += ["    )", "}", ""]
    return "\n".join(out)


def swift(rules: dict) -> str:
    out = [f"// {HEADER}", "", "enum GeneratedRules {", ""]

    out.append("    /// Params starting with any of these are stripped on every site.")
    out.append("    static let trackingPrefixes: [String] = [")
    for group in rules["trackingPrefixes"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['prefixes'])},")
    out += ["    ]", ""]

    out.append("    /// Params stripped on every site.")
    out.append("    static let trackingParams: Set<String> = [")
    for group in rules["trackingParams"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['params'])},")
    out += ["    ]", ""]

    out.append("    /// Params only stripped on specific sites, because their names are generic enough to mean")
    out.append("    /// something real elsewhere. Keys match the host and its subdomains; a key ending in \".*\"")
    out.append("    /// matches that name on any country domain (see `UrlCleaner.hostMatches`).")
    out.append("    static let siteParams: [String: Set<String>] = [")
    for group in rules["siteParams"]:
        out += comment_lines(group, "        // ")
        for site in group["sites"]:
            out.append(f"        {json.dumps(site)}: [{quoted(group['params'])}],")
    out += ["    ]", ""]

    out.append("    /// Hosts whose links are resolved (redirects followed) before cleaning.")
    out.append("    static let shortLinkHosts: Set<String> = [")
    for group in rules["shortLinkHosts"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['hosts'])},")
    out += ["    ]", "}", ""]
    return "\n".join(out)


def main() -> None:
    rules = json.loads(RULES.read_text(encoding="utf-8"))
    validate(rules)
    outputs = {KOTLIN: kotlin(rules), SWIFT: swift(rules)}

    if "--check" in sys.argv:
        stale = [path for path, text in outputs.items()
                 if not path.exists() or path.read_text(encoding="utf-8") != text]
        if stale:
            names = ", ".join(str(p.relative_to(ROOT)) for p in stale)
            sys.exit(f"Out of date: {names}\nRun: python3 shared/rules/generate.py")
        print("Generated rules are up to date.")
        return

    for path, text in outputs.items():
        path.write_text(text, encoding="utf-8")
        print(f"Wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
