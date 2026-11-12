#!/usr/bin/env python3
"""Finds tracking params and share sources Lint may be missing, using public lists only.

    python3 shared/research/research.py                      # fetch the lists, print the report
    python3 shared/research/research.py --out report.md      # write it to a file
    python3 shared/research/research.py --save DIR           # also keep what was downloaded
    python3 shared/research/research.py --offline DIR        # read previously downloaded files

It compares Lint's catalog (shared/rules/rules.json) with public tracking-param lists (ClearURLs,
AdGuard's URL Tracking filter, uBlock Origin's privacy filters, Firefox's query stripping list) and
ranks what it finds by how many lists agree and how popular the site is (the Tranco top list).
It never uses data from Lint's users, and it never changes the rules: it only writes a report.

The lists are read at run time as research signals. Several are GPL/LGPL-licensed, so nothing
from them is copied into this repo (see NOTES.md). Python 3 standard library only.
"""
import argparse
import base64
import csv
import datetime
import hashlib
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / "shared/rules/rules.json"
CASES = ROOT / "shared/tests/link-cases.json"
TARGETS = ROOT / "shared/tests/targets.json"

USER_AGENT = "Lint-param-research (+https://github.com/DavinKaru/Lint)"
MAX_DOWNLOAD = 64 * 1024 * 1024
ATTEMPTS = 3  # per mirror; big downloads sometimes arrive cut short
ISSUE_LIMIT = 65536


@dataclass
class Source:
    id: str
    name: str
    licence: str
    homepage: str
    offline_file: str
    # Each mirror is a list of URLs whose contents are joined; the first mirror that works wins.
    mirrors: list
    kind: str  # clearurls | filter | firefox | tranco


SOURCES = [
    Source("clearurls", "ClearURLs", "LGPL-3.0", "https://github.com/ClearURLs/Rules", "clearurls.json",
           [["https://rules2.clearurls.xyz/data.minify.json"],
            ["https://raw.githubusercontent.com/ClearURLs/Rules/master/data.min.json"]], "clearurls"),
    Source("adguard", "AdGuard URL Tracking", "GPL-3.0", "https://github.com/AdguardTeam/AdguardFilters", "adguard.txt",
           [["https://filters.adtidy.org/extension/ublock/filters/17.txt"],
            ["https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/TrackParamFilter/sections/general_url.txt",
             "https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/TrackParamFilter/sections/specific.txt"]],
           "filter"),
    Source("ublock", "uBlock Origin privacy", "GPL-3.0", "https://github.com/uBlockOrigin/uAssets", "ublock.txt",
           [["https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt"],
            ["https://ublockorigin.github.io/uAssets/filters/privacy.txt"]], "filter"),
    Source("firefox", "Firefox query stripping", "MPL-2.0", "https://firefox.settings.services.mozilla.com",
           "firefox.json",
           [["https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/query-stripping/records"]],
           "firefox"),
]
TRANCO = Source("tranco", "Tranco top 1M", "free to use, cite Tranco", "https://tranco-list.eu", "tranco.csv.zip",
                [["https://tranco-list.eu/top-1m.csv.zip"]], "tranco")


# --- Fetching -------------------------------------------------------------------------------

def fetch(url: str, timeout: float) -> bytes:
    """Downloads url. Raises RuntimeError naming the url on any failure."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = response.read(MAX_DOWNLOAD + 1)
    except Exception as error:  # noqa: BLE001 - every failure is reported, none is fatal
        raise RuntimeError(f"{url}: {type(error).__name__}: {error}") from error
    if len(data) > MAX_DOWNLOAD:
        raise RuntimeError(f"{url}: larger than {MAX_DOWNLOAD} bytes")
    return data


CHECKSUM = re.compile(r"^\s*!\s*checksum[\s\-:]+([\w+/=]+).*\n", re.I | re.M)


def verify_filter_text(url: str, data: bytes) -> None:
    """Raises if a filter list looks cut short. A text download can be truncated without any
    error, and would still parse. Lists with an Adblock Plus '! Checksum:' line are checked
    against it; others must at least end with a newline."""
    text = data.decode("utf-8", "replace")
    match = CHECKSUM.search(text)
    if match:
        body = CHECKSUM.sub("", re.sub(r"\n+", "\n", text.replace("\r", "")), count=1)
        digest = base64.b64encode(hashlib.md5(body.encode("utf-8")).digest()).decode().rstrip("=")
        if digest != match.group(1).rstrip("="):
            raise RuntimeError(f"{url}: checksum doesn't match (download cut short?)")
    elif not text.endswith("\n"):
        raise RuntimeError(f"{url}: doesn't end with a newline (download cut short?)")


def load(source: Source, parse, offline: Path | None, save: Path | None, timeout: float):
    """Returns parse(data) for the first mirror that downloads and parses (a download cut short
    usually fails to parse, so the next mirror is tried). Raises if none works."""
    if offline is not None:
        path = offline / source.offline_file
        if not path.exists() and source.kind == "tranco":
            path = offline / "tranco.csv"
        if not path.exists():
            raise FileNotFoundError(f"{path} not found")
        return parse(path.read_bytes()), path.name
    errors = []
    for mirror in source.mirrors:
        for attempt in range(ATTEMPTS):
            try:
                parts = [fetch(url, timeout) for url in mirror]
                if source.kind == "filter":
                    for url, part in zip(mirror, parts):
                        verify_filter_text(url, part)
                data = b"\n".join(parts)
                parsed = parse(data)
            except Exception as error:  # noqa: BLE001 - retry, then try the next mirror
                last = str(error) if isinstance(error, RuntimeError) else f"{' + '.join(mirror)}: {error}"
                if attempt + 1 < ATTEMPTS:
                    time.sleep(2 * (attempt + 1))
                continue
            if save is not None:
                save.mkdir(parents=True, exist_ok=True)
                (save / source.offline_file).write_bytes(data)
            return parsed, " + ".join(sorted({urllib.parse.urlsplit(url).hostname for url in mirror}))
        errors.append(last)
    raise RuntimeError("; ".join(errors))


# --- Small helpers --------------------------------------------------------------------------

def host_matches(host: str, domain: str) -> bool:
    """Same rule as UrlCleaner.hostMatches: domain or a subdomain; 'name.*' matches name followed by
    com, a two-letter country code, or com./co. plus one."""
    if not domain.endswith(".*"):
        return host == domain or host.endswith("." + domain)
    name = re.escape(domain[:-2])
    return re.fullmatch(rf"(.+\.)?{name}\.(com|[a-z]{{2}}|(com|co)\.[a-z]{{2}})", host) is not None


def site_matches(site: str, key: str) -> bool:
    """True if a list's site (a host, or 'name.*') is covered by a Lint site key."""
    if site == key:
        return True
    if site.endswith(".*"):
        # amazon.* is covered by amazon.* (above) or by a key that matches it on .com.
        return key.endswith(".*") and host_matches(site[:-2] + ".com", key)
    return host_matches(site, key)


SECOND_LEVEL = {"com", "co", "org", "net", "gov", "edu", "ac", "ne", "or", "go", "gob"}


def brand(domain: str) -> str:
    """The name part of a domain: amazon for www.amazon.co.uk, amazon.*, or smile.amazon.com."""
    d = domain.lower().strip(".")
    if d.endswith(".*"):
        return d[:-2].split(".")[-1]
    labels = d.split(".")
    if len(labels) >= 3 and labels[-2] in SECOND_LEVEL and len(labels[-1]) == 2:
        return labels[-3]
    return labels[-2] if len(labels) >= 2 else labels[0]


SITE = re.compile(r"^[a-z0-9-]+(\.[a-z0-9-]+)*(\.\*)?$")


def normalise_site(raw: str) -> str | None:
    """Lowercases, drops www. and *., and turns a trailing '.' (www.ebay.) into '.*'."""
    site = raw.strip().lower()
    if site.startswith("*."):
        site = site[2:]
    if site.endswith(".") and not site.endswith(".."):
        site = site + "*"
    if site.startswith("www."):
        site = site[4:]
    if "." not in site or not SITE.match(site):
        return None
    return site


class Unsupported(Exception):
    pass


LITERAL = re.compile(r"[A-Za-z0-9_\-%=\x00]")


def expand(pattern: str, limit: int = 32, dot_literal: bool = False) -> set | None:
    """Every string a simple regex matches: literals, backslash-escaped punctuation, (?:a|b) and
    (a|b) groups, [abc] classes and '?' after an atom. None for anything else (.*, ranges, \\d...)
    or if it would match more than `limit` strings. With dot_literal, a bare '.' is read as a dot
    (host patterns often forget to escape it)."""
    pos = 0

    def alternatives():
        nonlocal pos
        options = sequence()
        while pos < len(pattern) and pattern[pos] == "|":
            pos += 1
            options |= sequence()
        return options

    def sequence():
        nonlocal pos
        results = {""}
        while pos < len(pattern) and pattern[pos] not in "|)":
            options = atom()
            if pos < len(pattern) and pattern[pos] == "?":
                pos += 1
                options = options | {""}
            results = {a + b for a in results for b in options}
            if len(results) > limit:
                raise Unsupported
        return results

    def atom():
        nonlocal pos
        c = pattern[pos]
        if c == "\\":
            if pos + 1 >= len(pattern) or pattern[pos + 1].isalnum():
                raise Unsupported
            pos += 2
            return {pattern[pos - 1]}
        if c == "(":
            pos += 3 if pattern.startswith("(?:", pos) else 1
            inner = alternatives()
            if pos >= len(pattern) or pattern[pos] != ")":
                raise Unsupported
            pos += 1
            return inner
        if c == "[":
            end = pattern.find("]", pos)
            body = pattern[pos + 1:end] if end > 0 else ""
            if not re.fullmatch(r"[A-Za-z0-9_]+", body):
                raise Unsupported
            pos = end + 1
            return set(body)
        if LITERAL.match(c) or (dot_literal and c == "."):
            pos += 1
            return {c}
        raise Unsupported

    try:
        result = alternatives()
        if pos != len(pattern):
            raise Unsupported
    except (Unsupported, IndexError):
        return None
    return result


# --- Parsed lists ---------------------------------------------------------------------------

@dataclass
class ListData:
    """What one list says. Sites are normalised hosts or 'name.*'; None means every site."""
    params: set = field(default_factory=set)       # (kind, name, site|None), kind = param|prefix
    redirects: set = field(default_factory=set)    # sites with redirect/unwrap rules
    referral: set = field(default_factory=set)     # (name, site|None): affiliate IDs (ClearURLs)
    plain: int = 0
    regex: int = 0
    other: int = 0


NOISE = re.compile(r"\(\?:%3[Ff]\)\?")
WILD_TAIL = re.compile(r"(\.\*|\.\+|\[[^\]]*\][*+]|\\w[*+])$")
TLD_WILDCARD = re.compile(r"\(\?:\\\.\[a-z\]\{2,\}\)(\{1,\}|\+)")
SCHEME = re.compile(r"^\^?https\?:(\\/|/){2}")
SUBDOMAINS = re.compile(r"^\((\?:)?[^()]*\\\.\)(\*\?|\*|\?)?")
# ClearURLs' own self-test providers, not real sites.
TEST_PROVIDER = re.compile(r"^(ClearURLsTest.*|site\d*\.com)$")


def clearurls_param(rule: str) -> tuple[str, set | None]:
    """('param'|'prefix', names) for a ClearURLs rule, names None if it's a real regex."""
    text = NOISE.sub("", rule)
    kind = "param"
    tail = WILD_TAIL.search(text)
    if tail and tail.start() > 0:
        text, kind = text[:tail.start()], "prefix"
    return kind, expand(text)


def clearurls_sites(url_pattern: str) -> list | None:
    """The sites a ClearURLs urlPattern covers ([None] for every site), or None if unclear."""
    if url_pattern in (".*", "^.*", ".*$"):
        return [None]
    text = SCHEME.sub("", url_pattern)
    if text == url_pattern:
        return None
    text = SUBDOMAINS.sub("", text)
    text = TLD_WILDCARD.sub("\x00", text)
    depth, end = 0, len(text)
    for i, c in enumerate(text):
        if c == "(" and (i == 0 or text[i - 1] != "\\"):
            depth += 1
        elif c == ")" and text[i - 1] != "\\":
            depth -= 1
        elif depth == 0 and (c in "/$:" or text.startswith("\\/", i) or text.startswith("\\?", i)
                             or text.startswith(".*", i)):
            end = i
            break
    hosts = expand(text[:end], dot_literal=True)
    if not hosts:
        return None
    sites = {normalise_site(h.replace("\x00", ".*")) for h in hosts}
    return None if None in sites else sorted(sites)


def parse_clearurls(data: bytes) -> tuple[ListData, list]:
    """Returns the parsed list and the names of providers whose urlPattern couldn't be mapped."""
    providers = json.loads(data.decode("utf-8"))["providers"]
    out, unmapped = ListData(), []
    for name, provider in providers.items():
        if TEST_PROVIDER.match(name):
            continue
        sites = clearurls_sites(provider.get("urlPattern", ""))
        if sites is None:
            unmapped.append(name)
            continue
        if provider.get("completeProvider"):
            continue
        for rule in provider.get("rules", []):
            kind, names = clearurls_param(rule)
            if not names:
                out.regex += 1
                continue
            out.plain += 1
            for n in names:
                for site in sites:
                    out.params.add((kind, n, site))
        for rule in provider.get("referralMarketing", []):
            names = expand(NOISE.sub("", rule))
            for n in names or ():
                for site in sites:
                    out.referral.add((n, site))
        if provider.get("redirections"):
            out.redirects.update(s for s in sites if s)
    return out, unmapped


REGEX_VALUE = re.compile(r"^/(.*)/([a-z]*)$")
PLAIN_NAME = re.compile(r"^[A-Za-z0-9_.\-\[\]]+$")
PATTERN_HOST = re.compile(r"^(?:\|\|)([a-z0-9.*-]+)", re.I)
URL_HOST = re.compile(r"^\|?(?:https?)?://([a-z0-9.*-]+)", re.I)


def split_options(options: str) -> list:
    """Splits filter options on commas, keeping a /regex/ value (which may contain commas) whole."""
    parts, current, i = [], "", 0
    while i < len(options):
        c = options[i]
        if c == "/" and current.endswith("="):
            end = i + 1
            while end < len(options):
                if options[end] == "\\":
                    end += 2
                    continue
                if options[end] == "/":
                    break
                end += 1
            current += options[i:end + 1]
            i = end + 1
            continue
        if c == ",":
            parts.append(current)
            current = ""
        else:
            current += c
        i += 1
    parts.append(current)
    return [p.strip() for p in parts if p.strip()]


def filter_param(value: str) -> tuple[str, str] | None:
    """('param'|'prefix', name) for a removeparam value, None if it's a regex we can't read."""
    value = value[4:] if value.startswith("amp;") else value
    if PLAIN_NAME.match(value):
        return "param", value
    match = REGEX_VALUE.match(value)
    if not match:
        return None
    # Only the simplest regexes: /^name=/ or /^name$/ (one param) and /^name_/ (a prefix).
    body = match.group(1)
    simple = re.fullmatch(r"\^([A-Za-z0-9_\-]+)(=|\$)?", body) or re.fullmatch(r"\^([A-Za-z0-9_\-]+_)\\d\+", body)
    if not simple:
        return None
    if simple.lastindex == 2 and simple.group(2):
        return "param", simple.group(1)
    return "prefix", simple.group(1)


def filter_sites(pattern: str, options: dict) -> list | None:
    """Sites a filter applies to: to=, else domain=/from=, else the ||host in the pattern.
    [None] for a rule on every site, None if it's scoped some way we don't read."""
    for key in ("to", "domain", "from"):
        if key in options:
            wanted = [d for d in options[key].split("|") if d and not d.startswith("~")]
            if wanted:
                sites = sorted({s for s in map(normalise_site, wanted) if s})
                return sites or None
    if pattern in ("", "*"):
        return [None]
    match = PATTERN_HOST.match(pattern) or URL_HOST.match(pattern)
    if not match:
        return None
    raw = match.group(1)
    if "*" in raw[:-1] and not raw.endswith(".*"):
        return None
    site = normalise_site(raw if raw.endswith(".*") else raw.rstrip("*"))
    return [site] if site else None


def parse_filter(data: bytes) -> ListData:
    """Reads $removeparam (and uBO $urlskip) rules from an AdGuard/uBlock filter list."""
    out = ListData()
    for line in data.decode("utf-8", "replace").splitlines():
        line = line.strip()
        if not line or line[0] in "![#" or "##" in line or "#@#" in line or "#$#" in line or "#%#" in line:
            continue
        if "removeparam" not in line and "urlskip" not in line:
            continue
        if line.startswith("@@"):
            out.other += 1
            continue
        match = re.match(r"^(.*?)\$(.*(?:removeparam|urlskip).*)$", line)
        if not match:
            out.other += 1
            continue
        pattern, options = match.group(1), {}
        action = None
        for option in split_options(match.group(2)):
            key, _, value = option.partition("=")
            if key in ("removeparam", "urlskip"):
                action = (key, value)
            else:
                options[key] = value
        if action is None:
            out.other += 1
            continue
        sites = filter_sites(pattern, options)
        if sites is None:
            out.other += 1
            continue
        key, value = action
        if key == "urlskip":
            out.redirects.update(s for s in sites if s)
            continue
        if not value or value.startswith("~"):
            out.other += 1  # removes every param, or every param but one
            continue
        parsed = filter_param(value)
        if parsed is None:
            out.regex += 1
            continue
        out.plain += 1
        for site in sites:
            out.params.add((parsed[0], parsed[1], site))
    return out


def parse_firefox(data: bytes) -> ListData:
    out = ListData()
    for record in json.loads(data.decode("utf-8")).get("data", []):
        for name in record.get("stripList", []):
            if PLAIN_NAME.match(name):
                out.plain += 1
                out.params.add(("param", name, None))
    return out


def parse_tranco(data: bytes) -> dict:
    """{brand: best rank}. Accepts the zip or a plain rank,domain CSV."""
    if data[:2] == b"PK":
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            data = archive.read(archive.namelist()[0])
    ranks = {}
    for row in csv.reader(io.StringIO(data.decode("utf-8", "replace"))):
        if len(row) < 2 or not row[0].isdigit():
            continue
        name = brand(row[1])
        if name not in ranks:
            ranks[name] = int(row[0])
    return ranks


# --- Lint's own catalog ---------------------------------------------------------------------

URL = re.compile(r"https?://[^\s]+")


def host_of(url: str) -> str | None:
    return normalise_site(re.sub(r"^https?://([^/?#:]+).*", r"\1", url))


class Catalog:
    def __init__(self, rules: dict, cases: dict | None = None, targets: dict | None = None):
        self.prefixes = [p.lower() for g in rules["trackingPrefixes"] for p in g["prefixes"]]
        self.params = {p.lower() for g in rules["trackingParams"] for p in g["params"]}
        self.entries = [(g["sites"], {p.lower() for p in g["params"]}, g["source"]) for g in rules["siteParams"]]
        self.never = {p.lower() for g in rules.get("neverStrip", []) for p in g["params"]}
        self.unwrap_sites = [s for key in ("redirectWrappers", "pathWrappers", "shortLinkPaths")
                             for g in rules.get(key, []) for s in g["sites"]]
        self.unwrap_sites += [h for g in rules.get("shortLinkHosts", []) for h in g["hosts"]]
        self.kept = defaultdict(set)  # param -> {(host, case source)} kept in a link case's output
        self.target_hosts = []        # (target name, {hosts})
        self.target_names = []
        hosts_by_source = defaultdict(set)
        cases = cases or {}
        # Where each source's links live, to match list sites to targets. Unwrap cases only count
        # the wrapper's host, and only short links Lint knows.
        inputs = [(c["source"], c["input"]) for c in cases.get("clean", []) + cases.get("unwrap", [])]
        inputs += [(c["source"], c["url"]) for c in cases.get("shortLinks", []) if c.get("known")]
        for source, text in inputs:
            for url in URL.findall(text):
                host = host_of(url)
                if host:
                    hosts_by_source[source].add(host)
        # Params a case keeps in its expected output are kept on purpose (content IDs, variants).
        # The Generic cases use placeholder links, so they don't say anything about a real site.
        for case in cases.get("clean", []):
            if case["source"] == "Generic":
                continue
            for url in URL.findall(case["expected"]):
                host = host_of(url)
                query = url.split("#")[0].partition("?")[2]
                for pair in filter(None, query.split("&")):
                    if host:
                        self.kept[pair.split("=")[0].lower()].add((host, case["source"]))
        for target in (targets or {}).get("targets", []):
            hosts = set().union(*[hosts_by_source.get(s, set()) for s in target["sources"]] or [set()])
            self.target_hosts.append((target["name"], hosts))
            self.target_names.append((target["name"], re.sub(r"[^a-z0-9]", "", target["name"].lower().split(" ")[0])))

    def strips_globally(self, kind: str, name: str) -> bool:
        n = name.lower()
        if any(n.startswith(p) for p in self.prefixes):
            return True
        return kind == "param" and n in self.params

    def strips_on(self, kind: str, name: str, site: str) -> bool:
        if self.strips_globally(kind, name):
            return True
        return kind == "param" and any(
            name.lower() in params and any(site_matches(site, key) for key in sites)
            for sites, params, _ in self.entries)

    def entry_for(self, site: str) -> int | None:
        for index, (sites, _, _) in enumerate(self.entries):
            if any(site_matches(site, key) for key in sites):
                return index
        return None

    def sites_stripping(self, kind: str, name: str) -> list:
        return [source for _, params, source in self.entries
                if (name.lower() in params if kind == "param" else any(p.startswith(name.lower()) for p in params))]

    def unwraps(self, site: str) -> bool:
        # Site-level only: l.instagram.com in Lint counts for a list's instagram.com rule too.
        return any(site_matches(site, key) or site_matches(key, site) for key in self.unwrap_sites)

    def kept_by_case(self, name: str, sites) -> str | None:
        for host, source in self.kept.get(name.lower(), ()):
            if any(s is None or host_matches(host, s) or site_matches(s, host) for s in sites):
                return source
        return None

    def targets_for(self, sites) -> list:
        found = []
        for name, hosts in self.target_hosts:
            if any(host_matches(h, s) or site_matches(s, h) for h in hosts for s in sites):
                found.append(name)
        if not found:
            brands = {brand(s) for s in sites}
            found = [name for name, key in self.target_names if key in brands]
        return found


# --- Comparing ------------------------------------------------------------------------------

@dataclass
class Row:
    kind: str
    name: str
    sites: list
    lists: set
    group: str = ""
    rank: int | None = None
    targets: list = field(default_factory=list)
    note: str = ""


def display(kind: str, name: str) -> str:
    return f"`{name}*`" if kind == "prefix" else f"`{name}`"


def compare(lists: dict, catalog: Catalog, ranks: dict, min_lists: int) -> dict:
    """Builds every report table. `lists` maps list name -> ListData."""
    spelling = defaultdict(Counter)
    global_flags = defaultdict(set)                          # (kind, lower) -> {list}
    site_flags = defaultdict(lambda: (set(), set()))         # (kind, lower, group) -> ({list}, {site})
    group_label = {}
    for list_name, data in lists.items():
        for kind, name, site in data.params:
            key = (kind, name.lower())
            spelling[key][name] += 1
            if site is None:
                global_flags[key].add(list_name)
                continue
            entry = catalog.entry_for(site)
            group = f"lint:{entry}" if entry is not None else f"brand:{brand(site)}"
            group_label[group] = catalog.entries[entry][2] if entry is not None else brand(site)
            flagged, sites = site_flags[key + (group,)]
            flagged.add(list_name)
            sites.add(site)

    def best_rank(sites):
        found = [ranks[brand(s)] for s in sites if s and brand(s) in ranks]
        return min(found) if found else None

    def spelled(key):
        return spelling[key].most_common(1)[0][0]

    kept, global_rows, site_rows, single_rows = [], [], [], []
    for key, flagged in global_flags.items():
        kind, _ = key
        name = spelled(key)
        if kind == "param" and key[1] in catalog.never:
            kept.append(Row(kind, name, ["every site"], flagged, note="in neverStrip"))
            continue
        if catalog.strips_globally(kind, name) or len(flagged) < min_lists:
            continue
        source = catalog.kept_by_case(name, [None])
        if source:
            kept.append(Row(kind, name, ["every site"], flagged, note=f"kept in the {source} link case"))
            continue
        on_sites = catalog.sites_stripping(kind, name)
        note = ("Lint strips it on: " + ", ".join(on_sites[:3])) if on_sites else ""
        global_rows.append(Row(kind, name, ["every site"], flagged, note=note))

    for (kind, lower, group), (flagged, sites) in site_flags.items():
        key = (kind, lower)
        name = spelled(key)
        everyone = flagged | global_flags.get(key, set())
        sites = sorted(sites)
        if all(catalog.strips_on(kind, name, s) for s in sites):
            continue
        row = Row(kind, name, sites, everyone, group_label[group], best_rank(sites), catalog.targets_for(sites))
        if kind == "param" and lower in catalog.never:
            kept.append(Row(kind, name, sites, everyone, note="in neverStrip"))
            continue
        source = catalog.kept_by_case(name, sites)
        if source:
            kept.append(Row(kind, name, sites, everyone, note=f"kept in the {source} link case"))
            continue
        if len(global_flags.get(key, ())) >= min_lists and not catalog.strips_globally(kind, name):
            continue  # already in the global table
        if len(everyone) >= min_lists:
            site_rows.append(row)
        elif row.targets:
            single_rows.append(row)

    for list_name, data in lists.items():
        for name, site in data.referral:
            if site is None and catalog.strips_globally("param", name):
                continue
            if site is not None and catalog.strips_on("param", name, site):
                continue
            kept.append(Row("param", name, [site or "every site"], {list_name},
                            note="affiliate or referral ID (Lint keeps these for now, #28)"))

    # Share sources: sites several lists have rules for, with no Lint site rules and no target.
    sources = defaultdict(lambda: [set(), set(), set()])  # brand -> [lists, params, sites]
    for (kind, lower, group), (flagged, sites) in site_flags.items():
        if not group.startswith("brand:"):
            continue
        entry = sources[group[6:]]
        entry[0].update(flagged)
        entry[1].add(display(kind, spelled((kind, lower))))
        entry[2].update(sites)
    source_rows = []
    for name, (flagged, params, sites) in sources.items():
        if len(flagged) < min_lists or catalog.targets_for(sorted(sites)):
            continue
        row = Row("site", name, sorted(sites), flagged, name, best_rank(sites))
        row.note = ", ".join(sorted(params)[:6]) + (f" (+{len(params) - 6} more)" if len(params) > 6 else "")
        source_rows.append(row)

    # Redirect links: grouped by site name, shown if several lists agree or it's a target.
    redirects = defaultdict(lambda: (set(), set()))
    for list_name, data in lists.items():
        for site in data.redirects:
            if not catalog.unwraps(site):
                flagged, sites = redirects[brand(site)]
                flagged.add(list_name)
                sites.add(site)
    redirect_rows = []
    for name, (flagged, sites) in redirects.items():
        sites = sorted(sites)
        row = Row("site", name, sites, flagged, name, best_rank(sites), catalog.targets_for(sites))
        if len(flagged) >= min_lists or row.targets:
            redirect_rows.append(row)

    def order(row):
        return (-len(row.lists), not row.targets, row.rank or 10 ** 9, row.name.lower())

    for rows in (global_rows, site_rows, single_rows, redirect_rows):
        rows.sort(key=order)
    source_rows.sort(key=lambda r: (r.rank or 10 ** 9, -len(r.lists), r.name))

    # One kept row per param and reason, however many sites the lists name.
    merged = {}
    for row in kept:
        key = (row.kind, row.name.lower(), row.note)
        if key in merged:
            merged[key].sites = sorted(set(merged[key].sites) | set(row.sites))
            merged[key].lists |= row.lists
        else:
            merged[key] = Row(row.kind, row.name, sorted(row.sites), set(row.lists), note=row.note)
    kept = sorted(merged.values(), key=lambda r: (-len(r.lists), r.name.lower()))
    return {"global": global_rows, "site": site_rows, "single": single_rows,
            "sources": source_rows, "redirects": redirect_rows, "kept": kept}


# --- Report ---------------------------------------------------------------------------------

HEADER = """# Param research report

Generated {date} by [`shared/research/research.py`](https://github.com/DavinKaru/Lint/blob/main/shared/research/research.py).

> **This report never adds rules.** It's a list of leads from public tracking-param lists, ranked by
> how many lists agree and how popular the site is. Every candidate goes through the normal routine
> before it lands in `rules.json`: share a real link from the app, add a test case to
> `shared/tests/link-cases.json`, and check the cleaned link still opens the same thing. Lists strip
> some params Lint keeps on purpose (content IDs, variant selectors, affiliate IDs); those are at the
> bottom, for information only.
>
> Only public lists are used, read at run time. Nothing comes from Lint's users: Lint has no
> telemetry. The lists are not copied into the repo (several are GPL-licensed, see NOTES.md).

Cards for the [Link support board](https://github.com/users/DavinKaru/projects/1) are added by hand
from this report.
"""


def esc(text: str) -> str:
    return text.replace("|", "\\|")


def short_sites(sites, limit=3) -> str:
    shown = [f"`{s}`" for s in sites[:limit]]
    return ", ".join(shown) + (f" +{len(sites) - limit}" if len(sites) > limit else "")


def table(rows, limit, columns) -> list:
    if not rows:
        return ["_None._", ""]
    lines = ["| " + " | ".join(c[0] for c in columns) + " |", "|" + "---|" * len(columns)]
    for row in rows[:limit]:
        lines.append("| " + " | ".join(esc(str(c[1](row))) for c in columns) + " |")
    if len(rows) > limit:
        lines.append(f"\n_{len(rows) - limit} more not shown._")
    return lines + [""]


def lists_cell(row):
    return f"{len(row.lists)}: " + ", ".join(sorted(row.lists))


def rank_cell(row):
    return f"{row.rank:,}" if row.rank else "-"


def target_cell(row):
    return ", ".join(row.targets[:2]) if row.targets else "-"


def render(tables: dict, status: list, extra: list, limit: int, min_lists: int, date: str) -> str:
    param_cols = [("Param", lambda r: display(r.kind, r.name)), ("Lists", lists_cell), ("Notes", lambda r: r.note or "-")]
    site_cols = [("Param", lambda r: display(r.kind, r.name)), ("Site", lambda r: short_sites(r.sites)),
                 ("Lists", lists_cell), ("Tranco", rank_cell), ("Target", target_cell)]
    out = [HEADER.format(date=date), "## Sources", "",
           "| List | Licence | Status | Plain rules | Regex rules skipped | Other lines skipped |", "|---|---|---|---|---|---|"]
    out += status + [""] + extra + [""]
    out += [f"## Params stripped on every site by {min_lists}+ lists that Lint doesn't strip everywhere",
            "", "Ranked by how many lists agree. A global rule needs a name that can't mean anything else; "
            "otherwise prefer a site rule.", ""]
    out += table(tables["global"], limit, param_cols)
    out += [f"## Site params flagged by {min_lists}+ lists that Lint doesn't strip there", "",
            "Counts a list that strips the param everywhere too. Ranked by agreement, then target sites, then popularity.", ""]
    out += table(tables["site"], limit, site_cols)
    out += ["## Target sites: params flagged by one list", "", "Sites on the 1.0 target list, so worth a look even with one list.", ""]
    out += table(tables["single"], limit, site_cols)
    out += ["## Popular sites the lists cover that aren't Lint targets", "",
            f"Possible new share sources: sites with site-specific rules in {min_lists}+ lists, no Lint site rules "
            "and no target card. Ranked by popularity.", ""]
    out += table(tables["sources"], limit, [("Site", lambda r: f"`{r.name}`"), ("Domains", lambda r: short_sites(r.sites)),
                                            ("Lists", lists_cell), ("Tranco", rank_cell), ("Params flagged", lambda r: r.note)])
    out += ["## Redirect links the lists unwrap that Lint doesn't", "", f"Shown when {min_lists}+ lists agree or the site is a target. Compared by site only, not path.", ""]
    out += table(tables["redirects"], limit, [("Site", lambda r: f"`{r.name}`"), ("Hosts", lambda r: short_sites(r.sites)),
                                              ("Lists", lists_cell), ("Tranco", rank_cell), ("Target", target_cell)])
    out += ["## Kept on purpose (for information)", "",
            "Params the lists strip that Lint deliberately keeps. No action needed unless the reason has changed.", ""]
    out += table(tables["kept"], limit, [("Param", lambda r: display(r.kind, r.name)), ("Sites", lambda r: short_sites(r.sites)),
                                         ("Lists", lists_cell), ("Why Lint keeps it", lambda r: r.note)])
    return "\n".join(out)


def build(lists_status: dict, lists: dict, catalog: Catalog, ranks: dict, args, extra: list) -> str:
    tables = compare(lists, catalog, ranks, args.min_lists)
    date = args.date or datetime.date.today().isoformat()
    limit = args.limit
    while True:
        report = render(tables, lists_status, extra, limit, args.min_lists, date)
        if len(report) <= args.max_chars or limit <= 5:
            break
        limit = max(5, limit * 3 // 4)
    if len(report) > args.max_chars:
        report = report[:args.max_chars - 60] + "\n\n_Report cut short to fit the issue size limit._\n"
    return report


def checked(parse):
    """Wraps a parser so a download that yields nothing (an error page, say) counts as a failure."""
    def run(data: bytes):
        result = parse(data)
        found = result[0] if isinstance(result, tuple) else result
        if not (found.plain if isinstance(found, ListData) else found):
            raise ValueError("nothing usable in the download")
        return result
    return run


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--offline", type=Path, help="read previously downloaded lists from this directory")
    parser.add_argument("--save", type=Path, help="keep downloaded lists in this directory (don't commit it)")
    parser.add_argument("--out", type=Path, help="write the report here instead of stdout")
    parser.add_argument("--limit", type=int, default=60, help="rows per table (default 60)")
    parser.add_argument("--min-lists", type=int, default=2, help="lists that must agree (default 2)")
    parser.add_argument("--max-chars", type=int, default=ISSUE_LIMIT - 1536, help="report size cap")
    parser.add_argument("--timeout", type=float, default=60, help="seconds per download")
    parser.add_argument("--date", help="date shown in the report (default today)")
    parser.add_argument("--rules", type=Path, default=RULES)
    parser.add_argument("--cases", type=Path, default=CASES)
    parser.add_argument("--targets", type=Path, default=TARGETS)
    args = parser.parse_args(argv)

    catalog = Catalog(json.loads(args.rules.read_text(encoding="utf-8")),
                      json.loads(args.cases.read_text(encoding="utf-8")) if args.cases.exists() else None,
                      json.loads(args.targets.read_text(encoding="utf-8")) if args.targets.exists() else None)
    lists, status, extra, ranks = {}, [], [], {}
    for source in SOURCES + [TRANCO]:
        link = f"[{source.name}]({source.homepage})"
        try:
            if source.kind == "tranco":
                ranks, origin = load(source, checked(parse_tranco), args.offline, args.save, args.timeout)
                status.append(f"| {link} | {source.licence} | ok via {origin} ({len(ranks):,} names) | - | - | - |")
                continue
            if source.kind == "clearurls":
                (parsed, unmapped), origin = load(source, checked(parse_clearurls), args.offline, args.save, args.timeout)
                if unmapped:
                    extra.append(f"ClearURLs providers whose site couldn't be read ({len(unmapped)}): "
                                 + ", ".join(f"`{n}`" for n in sorted(unmapped)[:20])
                                 + (" ..." if len(unmapped) > 20 else ""))
            else:
                parser = parse_filter if source.kind == "filter" else parse_firefox
                parsed, origin = load(source, checked(parser), args.offline, args.save, args.timeout)
            lists[source.name] = parsed
            status.append(f"| {link} | {source.licence} | ok via {origin} | {parsed.plain:,} | {parsed.regex:,} | {parsed.other:,} |")
        except Exception as error:  # noqa: BLE001 - a failed source is reported and skipped
            message = esc(str(error))[:300]
            status.append(f"| {link} | {source.licence} | **failed**: {message} | - | - | - |")
            print(f"warning: {source.name}: {error}", file=sys.stderr)

    if not lists:
        print("error: no tracking-param list could be loaded, so there's nothing to report", file=sys.stderr)
        return 2
    report = build(status, lists, catalog, ranks, args, extra)
    if args.out:
        args.out.write_text(report, encoding="utf-8")
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
