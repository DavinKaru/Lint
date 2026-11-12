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
    check_literals(rules)
    check_keys(rules)
    params = [p for group in rules["trackingParams"] for p in group["params"]]
    prefixes = [p for group in rules["trackingPrefixes"] for p in group["prefixes"]]
    hosts = [h for group in rules["shortLinkHosts"] for h in group["hosts"]]
    # A site can have one site-wide siteParams entry; entries with paths are separate rules.
    sites = [s for group in rules["siteParams"] if "paths" not in group for s in group["sites"]]

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
    for site in (s for group in rules["siteParams"] for s in group["sites"]):
        if not SITE_KEY.match(site):
            fail(f'site "{site}" should be a lowercase domain, optionally ending in ".*"')
    for group in rules["siteParams"]:
        if "paths" in group:
            check_segment_paths(group["paths"], f'siteParams "{group["source"]}"')
    for host in hosts:
        if not HOST.match(host):
            fail(f'short-link host "{host}" should be a lowercase domain')

    for group in rules.get("redirectWrappers", []):
        label = group["source"]
        if not group["sites"] or not group["paths"] or not group["params"]:
            fail(f'redirect wrapper "{label}" needs sites, paths and params')
        for site in group["sites"]:
            if not SITE_KEY.match(site):
                fail(f'redirect wrapper "{label}": site "{site}" should be a lowercase domain')
        for path in group["paths"]:
            if not path.startswith("/") or "*" in path[:-1]:
                fail(f'redirect wrapper "{label}": path "{path}" should start with "/" and may only end in "*"')
        prefix = group.get("base64Prefix")
        if prefix is not None and not re.fullmatch(r"[A-Za-z0-9]+", prefix):
            fail(f'redirect wrapper "{label}": base64Prefix should be letters and digits')
        for site in group.get("targetSites", []):
            if not SITE_KEY.match(site):
                fail(f'redirect wrapper "{label}": target site "{site}" should be a lowercase domain')
        if "targetSites" in group and not group["targetSites"]:
            fail(f'redirect wrapper "{label}": targetSites, when given, must not be empty')
    check_listed_once(rules.get("redirectWrappers", []), lambda g: [(s, p) for s in g["sites"] for p in g["paths"]], "redirect wrappers listed twice")
    check_listed_once(rules.get("pathWrappers", []), lambda g: [(s, g["prefix"]) for s in g["sites"]], "path wrappers listed twice")
    scoped = [(s, normal_path(p), q, g["source"]) for g in rules["siteParams"] if "paths" in g
              for s in g["sites"] for p in g["paths"] for q in g["params"]]
    for i, (s1, p1, q1, src1) in enumerate(scoped):
        for s2, p2, q2, src2 in scoped[i + 1:]:
            if p1 == p2 and q1 == q2 and sites_overlap(s1, s2):
                fail(f'path-scoped siteParams listed twice: "{q1}" on {s1} and {s2} {p1} ({src1}, {src2})')
    for section, kind, key in (("shortLinkPaths", "short-link path", "provider"), ("deadEndPages", "dead-end page", "source")):
        for group in rules.get(section, []):
            label = group[key]
            if not group["sites"] or not group["paths"]:
                fail(f'{kind} "{label}" needs sites and paths')
            for site in group["sites"]:
                if not SITE_KEY.match(site):
                    fail(f'{kind} "{label}": site "{site}" should be a lowercase domain')
            check_segment_paths(group["paths"], f'{kind} "{label}"')
            if not isinstance(group.get("identifiesYou", False), bool) or ("identifiesYou" in group and section != "shortLinkPaths"):
                fail(f'{kind} "{label}": identifiesYou should be true or false, and only on shortLinkPaths')
        check_listed_once(rules.get(section, []), lambda g: [(s, normal_path(p)) for s in g["sites"] for p in g["paths"]], f"{section} listed twice")
    for group in rules.get("pathWrappers", []):
        label = group["source"]
        for site in group["sites"]:
            if not SITE_KEY.match(site):
                fail(f'path wrapper "{label}": site "{site}" should be a lowercase domain')
        if not (group["prefix"].startswith("/") and group["prefix"].endswith("/")):
            fail(f'path wrapper "{label}": prefix should start and end with "/"')
        if group["scheme"] not in ("http", "https"):
            fail(f'path wrapper "{label}": scheme should be http or https')
    for group in rules["siteParams"]:
        if "paths" not in group:
            continue
        if not group["sites"] or not group["params"]:
            fail(f'siteParams "{group["source"]}" needs sites and params')
        # A pattern of only "*" and "**" segments ("/*/**", "/*") would also cover search pages like
        # Amazon's /s, where the same param is the content.
        if any(all(seg in ("*", "**") for seg in path.strip("/").split("/")) for path in group["paths"]):
            fail(f'siteParams "{group["source"]}": every path needs at least one named segment; '
                 'one made only of "*" and "**" covers almost the whole site')
        for site in group["sites"]:
            wide = {p for g in rules["siteParams"] if "paths" not in g
                    for s in g["sites"] if sites_overlap(site, s) for p in g["params"]}
            for param in group["params"]:
                if param in params or param in wide or any(param.startswith(x) for x in prefixes):
                    fail(f'siteParams "{group["source"]}": "{param}" is already stripped everywhere on {site}')

    check_affiliates(rules, params, prefixes)


def check_affiliates(rules: dict, params: list, prefixes: list) -> None:
    """Lint keeps affiliate IDs (#28): no rule may strip an affiliateParams param on its site."""
    if not rules.get("affiliateParams"):
        fail("affiliateParams is missing or empty: it records the affiliate IDs Lint keeps (#28)")
    for group in rules["affiliateParams"]:
        if not group.get("source") or not group.get("sites") or not group.get("params"):
            fail(f'affiliate params "{group.get("source", "?")}" needs a source, sites and params')
        for site in group["sites"]:
            if not SITE_KEY.match(site):
                fail(f'affiliate params "{group["source"]}": site "{site}" should be a lowercase domain')
        for param in group["params"]:
            if param in params or any(param.startswith(x) for x in prefixes):
                fail(f'"{param}" is an affiliate param ({group["source"]}), so it can\'t be stripped on every site')
            for rule in rules["siteParams"]:
                if param in rule["params"] and any(sites_overlap(s, a) for s in rule["sites"] for a in group["sites"]):
                    fail(f'siteParams "{rule["source"]}" strips "{param}", an affiliate param ({group["source"]}) that Lint keeps')


def check_listed_once(groups: list, keys, message: str) -> None:
    """Fails if any key (e.g. a (site, path) pair) comes from more than one place."""
    pairs = [k for group in groups for k in keys(group)]
    repeated = sorted({" ".join(k) for k in pairs if pairs.count(k) > 1})
    if repeated:
        fail(f"{message}: {', '.join(repeated)}")


ALLOWED_KEYS = {
    "trackingPrefixes": {"prefixes", "source", "notes"},
    "trackingParams": {"params", "source", "notes"},
    "siteParams": {"sites", "paths", "params", "source", "notes"},
    "shortLinkHosts": {"hosts", "provider", "notes"},
    "neverStrip": {"params", "source", "notes"},
    "redirectWrappers": {"sites", "paths", "params", "base64Prefix", "targetSites", "source", "notes"},
    "pathWrappers": {"sites", "prefix", "scheme", "source", "notes"},
    "shortLinkPaths": {"sites", "paths", "identifiesYou", "provider", "notes"},
    "deadEndPages": {"sites", "paths", "source", "notes"},
    "affiliateParams": {"sites", "params", "source", "notes"},
}


def check_keys(rules: dict) -> None:
    """Refuses unknown sections and keys, so a typo (e.g. "path" for "paths") can't silently widen a rule."""
    for section, groups in rules.items():
        if section in ("_about", "version"):
            continue
        if section not in ALLOWED_KEYS:
            fail(f'unknown section "{section}"')
        for group in groups:
            unknown = sorted(set(group) - ALLOWED_KEYS[section])
            if unknown:
                fail(f'{section} "{group.get("source", group.get("provider"))}": unknown key {", ".join(unknown)}')


def sites_overlap(a: str, b: str) -> bool:
    """True if some host could match both site keys (same matching as UrlCleaner.hostMatches)."""
    def matches(host: str, key: str) -> bool:
        if not key.endswith(".*"):
            return host == key or host.endswith("." + key)
        name = re.escape(key[:-2])
        return re.fullmatch(rf"(.+\.)?{name}\.(com|[a-z]{{2}}|(com|co)\.[a-z]{{2}})", host) is not None
    def hosts(key: str, other: str) -> list:
        """Hosts key matches, tried against other: a wildcard gets .com and the other key's own
        ending, so www.amazon.* meets amazon.co.uk (at www.amazon.co.uk)."""
        if not key.endswith(".*"):
            return [key]
        # One of each ending a wildcard matches ("com", "uk", "com.au", "co.uk"), so that
        # amazon.* meets amazon.com.* and amazon.co.*, plus the other key's own ending.
        endings = {"com", "uk", "com.au", "co.uk"}
        if not other.endswith(".*"):
            labels = other.split(".")
            # Only endings a wildcard can have: kickstarter.com's "kickstarter.com" isn't one.
            endings |= {e for e in (labels[-1], ".".join(labels[-2:]))
                        if re.fullmatch(r"com|[a-z]{2}|(com|co)\.[a-z]{2}", e)}
        return [f"{key[:-2]}.{ending}" for ending in endings]
    return any(matches(h, b) for h in hosts(a, b)) or any(matches(h, a) for h in hosts(b, a))


def normal_path(path: str) -> str:
    """A path pattern without its trailing slash, so "/dp/*" and "/dp/*/" compare equal."""
    return "/" + path.strip("/")


def check_segment_paths(paths: list, label: str) -> None:
    """Segment patterns: "/"-separated names, "*" for any one segment, and a final "**" for any rest."""
    if not paths:
        fail(f"{label}: paths, when given, must not be empty")
    for path in paths:
        segments = path.strip("/").split("/")
        if not path.startswith("/") or any(not s or ("*" in s and s not in ("*", "**")) for s in segments) or "**" in segments[:-1]:
            fail(f'{label}: "{path}" should be "/"-separated segments, each a name or a whole "*", optionally ending in "**"')
        # Paths are matched before the query and still percent-encoded, so a pattern with "?", "#",
        # "%", a space or other characters a URL path never holds unencoded could never match.
        if not re.fullmatch(r"[A-Za-z0-9._~!&'()*+,;=:@/-]+", path):
            fail(f'{label}: "{path}" can only hold characters a URL path keeps unencoded (no "?", "#", "%" or spaces)')


def check_literals(rules: dict) -> None:
    """Every value emitted as a Kotlin/Swift string literal must mean the same in both: printable
    ASCII with no "$" (a Kotlin template) and no backslash. source/notes become comments, so they
    just need to stay on one line."""
    def walk(value, key=None):
        if isinstance(value, dict):
            for k, v in value.items():
                walk(v, k)
        elif isinstance(value, list):
            for v in value:
                walk(v, key)
        elif isinstance(value, str):
            if key in ("source", "provider", "notes", "_about"):
                if "\n" in value or "\r" in value:
                    fail(f"{key} should be one line: {value[:60]!r}")
            elif not re.fullmatch(r"[ -~]*", value) or "$" in value or "\\" in value:
                fail(f'"{value}" should be printable ASCII without "$" or "\\"')
    walk(rules)


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
        if "paths" in group:
            continue
        out += comment_lines(group, "        // ")
        for site in group["sites"]:
            out.append(f"        {json.dumps(site)} to setOf({quoted(group['params'])}),")
    out += ["    )", ""]

    out.append("    /** Params only stripped on some pages of a site (see UrlCleaner.pathMatches). */")
    out.append("    val SITE_PATH_PARAMS: List<SitePathParams> = listOf(")
    for group in rules["siteParams"]:
        if "paths" not in group:
            continue
        out += comment_lines(group, "        // ")
        out.append(f"        SitePathParams(listOf({quoted(group['sites'])}), listOf({quoted(group['paths'])}), setOf({quoted(group['params'])})),")
    out += ["    )", ""]

    out.append("    /** Hosts whose links are resolved (redirects followed) before cleaning. */")
    out.append("    val SHORT_LINK_HOSTS: Set<String> = setOf(")
    for group in rules["shortLinkHosts"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['hosts'])},")
    out += ["    )", ""]

    out.append("    /** Short links that live on a path of a normal site (see UrlCleaner.pathMatches). */")
    out.append("    val SHORT_LINK_PATHS: List<ShortLinkPath> = listOf(")
    for group in rules.get("shortLinkPaths", []):
        out += comment_lines(group, "        // ")
        extra = ", identifiesYou = true" if group.get("identifiesYou") else ""
        out.append(f"        ShortLinkPath(listOf({quoted(group['sites'])}), listOf({quoted(group['paths'])}){extra}),")
    out += ["    )", ""]

    out.append("    /** Redirect links that carry the real link in a query param; unwrapped offline. */")
    out.append("    val REDIRECT_WRAPPERS: List<RedirectWrapper> = listOf(")
    for group in rules.get("redirectWrappers", []):
        out += comment_lines(group, "        // ")
        extra = f", base64Prefix = {json.dumps(group['base64Prefix'])}" if "base64Prefix" in group else ""
        if "targetSites" in group:
            extra += f", targetSites = listOf({quoted(group['targetSites'])})"
        out.append(f"        RedirectWrapper(listOf({quoted(group['sites'])}), listOf({quoted(group['paths'])}), listOf({quoted(group['params'])}){extra}),")
    out += ["    )", ""]

    out.append("    /** Redirect links that carry the real link in their path; unwrapped offline. */")
    out.append("    val PATH_WRAPPERS: List<PathWrapper> = listOf(")
    for group in rules.get("pathWrappers", []):
        out += comment_lines(group, "        // ")
        out.append(f"        PathWrapper(listOf({quoted(group['sites'])}), {json.dumps(group['prefix'])}, {json.dumps(group['scheme'])}),")
    out += ["    )", ""]

    out.append("    /** Sign-in and consent pages: a short link that redirects to one stops at the hop before. */")
    out.append("    val DEAD_END_PAGES: List<SitePaths> = listOf(")
    for group in rules.get("deadEndPages", []):
        out += comment_lines(group, "        // ")
        out.append(f"        SitePaths(listOf({quoted(group['sites'])}), listOf({quoted(group['paths'])})),")
    out += ["    )", "}", ""]

    out.append("/**")
    out.append(" * A redirect on [sites] at [paths] (a trailing \"*\" matches any rest) whose first valid [params] value is the real")
    out.append(" * link: percent-encoded, or if [base64Prefix] is set, that prefix followed by the link in unpadded base64url.")
    out.append(" * If [targetSites] is set, the real link must be on one of them, or the wrapper is left alone.")
    out.append(" */")
    out.append("internal data class RedirectWrapper(")
    out.append("    val sites: List<String>,")
    out.append("    val paths: List<String>,")
    out.append("    val params: List<String>,")
    out.append("    val base64Prefix: String? = null,")
    out.append("    val targetSites: List<String>? = null,")
    out.append(")")
    out.append("")
    out.append("/** A redirect on [sites] whose path after [prefix] is the real link, without its [scheme]. */")
    out.append("internal data class PathWrapper(val sites: List<String>, val prefix: String, val scheme: String)")
    out.append("")
    out.append("/**")
    out.append(" * Short links on [sites] whose path matches one of [paths] (see UrlCleaner.pathMatches). If [identifiesYou],")
    out.append(" * the link itself identifies the person sharing it, so it's never kept in place of a sign-in page.")
    out.append(" */")
    out.append("internal data class ShortLinkPath(val sites: List<String>, val paths: List<String>, val identifiesYou: Boolean = false)")
    out.append("")
    out.append("/** [params] stripped on [sites], but only where the path matches one of [paths] (see UrlCleaner.pathMatches). */")
    out.append("internal data class SitePathParams(val sites: List<String>, val paths: List<String>, val params: Set<String>)")
    out.append("")
    out.append("/** Pages on [sites] whose path matches one of [paths] (see UrlCleaner.pathMatches). */")
    out.append("internal data class SitePaths(val sites: List<String>, val paths: List<String>)")
    out.append("")
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
        if "paths" in group:
            continue
        out += comment_lines(group, "        // ")
        for site in group["sites"]:
            out.append(f"        {json.dumps(site)}: [{quoted(group['params'])}],")
    out += ["    ]", ""]

    out.append("    /// Params only stripped on some pages of a site (see `UrlCleaner.pathMatches`).")
    out.append("    static let sitePathParams: [SitePathParams] = [")
    for group in rules["siteParams"]:
        if "paths" not in group:
            continue
        out += comment_lines(group, "        // ")
        out.append(f"        SitePathParams(sites: [{quoted(group['sites'])}], paths: [{quoted(group['paths'])}], params: [{quoted(group['params'])}]),")
    out += ["    ]", ""]

    out.append("    /// Hosts whose links are resolved (redirects followed) before cleaning.")
    out.append("    static let shortLinkHosts: Set<String> = [")
    for group in rules["shortLinkHosts"]:
        out += comment_lines(group, "        // ")
        out.append(f"        {quoted(group['hosts'])},")
    out += ["    ]", ""]

    out.append("    /// Short links that live on a path of a normal site (see `UrlCleaner.pathMatches`).")
    out.append("    static let shortLinkPaths: [ShortLinkPath] = [")
    for group in rules.get("shortLinkPaths", []):
        out += comment_lines(group, "        // ")
        extra = ", identifiesYou: true" if group.get("identifiesYou") else ""
        out.append(f"        ShortLinkPath(sites: [{quoted(group['sites'])}], paths: [{quoted(group['paths'])}]{extra}),")
    out += ["    ]", ""]

    out.append("    /// Redirect links that carry the real link in a query param; unwrapped offline.")
    out.append("    static let redirectWrappers: [RedirectWrapper] = [")
    for group in rules.get("redirectWrappers", []):
        out += comment_lines(group, "        // ")
        extra = f", base64Prefix: {json.dumps(group['base64Prefix'])}" if "base64Prefix" in group else ""
        if "targetSites" in group:
            extra += f", targetSites: [{quoted(group['targetSites'])}]"
        out.append(f"        RedirectWrapper(sites: [{quoted(group['sites'])}], paths: [{quoted(group['paths'])}], params: [{quoted(group['params'])}]{extra}),")
    out += ["    ]", ""]

    out.append("    /// Redirect links that carry the real link in their path; unwrapped offline.")
    out.append("    static let pathWrappers: [PathWrapper] = [")
    for group in rules.get("pathWrappers", []):
        out += comment_lines(group, "        // ")
        out.append(f"        PathWrapper(sites: [{quoted(group['sites'])}], prefix: {json.dumps(group['prefix'])}, scheme: {json.dumps(group['scheme'])}),")
    out += ["    ]", ""]

    out.append("    /// Sign-in and consent pages: a short link that redirects to one stops at the hop before.")
    out.append("    static let deadEndPages: [SitePaths] = [")
    for group in rules.get("deadEndPages", []):
        out += comment_lines(group, "        // ")
        out.append(f"        SitePaths(sites: [{quoted(group['sites'])}], paths: [{quoted(group['paths'])}]),")
    out += ["    ]", "}", ""]

    out.append("/// A redirect on `sites` at `paths` (a trailing \"*\" matches any rest) whose first valid `params` value is the real")
    out.append("/// link: percent-encoded, or if `base64Prefix` is set, that prefix followed by the link in unpadded base64url.")
    out.append("/// If `targetSites` is set, the real link must be on one of them, or the wrapper is left alone.")
    out.append("struct RedirectWrapper: Sendable {")
    out.append("    let sites: [String]")
    out.append("    let paths: [String]")
    out.append("    let params: [String]")
    out.append("    var base64Prefix: String? = nil")
    out.append("    var targetSites: [String]? = nil")
    out.append("}")
    out.append("")
    out.append("/// Short links on `sites` whose path matches one of `paths` (see `UrlCleaner.pathMatches`). If `identifiesYou`,")
    out.append("/// the link itself identifies the person sharing it, so it's never kept in place of a sign-in page.")
    out.append("struct ShortLinkPath: Sendable {")
    out.append("    let sites: [String]")
    out.append("    let paths: [String]")
    out.append("    var identifiesYou = false")
    out.append("}")
    out.append("")
    out.append("/// `params` stripped on `sites`, but only where the path matches one of `paths` (see `UrlCleaner.pathMatches`).")
    out.append("struct SitePathParams: Sendable {")
    out.append("    let sites: [String]")
    out.append("    let paths: [String]")
    out.append("    let params: Set<String>")
    out.append("}")
    out.append("")
    out.append("/// Pages on `sites` whose path matches one of `paths` (see `UrlCleaner.pathMatches`).")
    out.append("struct SitePaths: Sendable {")
    out.append("    let sites: [String]")
    out.append("    let paths: [String]")
    out.append("}")
    out.append("")
    out.append("/// A redirect on `sites` whose path after `prefix` is the real link, without its `scheme`.")
    out.append("struct PathWrapper: Sendable {")
    out.append("    let sites: [String]")
    out.append("    let prefix: String")
    out.append("    let scheme: String")
    out.append("}")
    out.append("")
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
