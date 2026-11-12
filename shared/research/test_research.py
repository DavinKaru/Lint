"""Tests for research.py, using the hand-written fixtures in fixtures/ (no network).

    python3 -m unittest discover -s shared/research
"""
import io
import json
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import research  # noqa: E402

FIXTURES = HERE / "fixtures"


def run(offline: Path, *extra: str) -> tuple[int, str]:
    """Runs the script offline against the fixture catalog and returns (exit code, report)."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "report.md"
        with redirect_stderr(io.StringIO()):
            code = research.main(["--offline", str(offline), "--out", str(out), "--date", "2026-01-01",
                                  "--rules", str(FIXTURES / "rules.json"),
                                  "--cases", str(FIXTURES / "link-cases.json"),
                                  "--targets", str(FIXTURES / "targets.json"), *extra])
        return code, out.read_text(encoding="utf-8") if out.exists() else ""


def section(report: str, heading: str) -> str:
    """The text of one '## ...' section, starting with the given words."""
    start = report.index("## " + heading)
    end = report.find("\n## ", start + 1)
    return report[start:end if end > 0 else None]


class HelperTests(unittest.TestCase):
    def test_host_matches_follows_url_cleaner(self):
        self.assertTrue(research.host_matches("eventbrite.com.au", "eventbrite.*"))
        self.assertTrue(research.host_matches("www.eventbrite.co.uk", "eventbrite.*"))
        self.assertFalse(research.host_matches("noteventbrite.com", "eventbrite.*"))
        self.assertFalse(research.host_matches("eventbrite.evil.com", "eventbrite.*"))
        self.assertTrue(research.host_matches("m.youtube.com", "youtube.com"))
        self.assertFalse(research.host_matches("notyoutube.com", "youtube.com"))

    def test_site_matches_wildcards(self):
        self.assertTrue(research.site_matches("shop.*", "shop.*"))
        self.assertTrue(research.site_matches("shop.co.uk", "shop.*"))
        self.assertFalse(research.site_matches("shop.*", "shop.com"))

    def test_brand(self):
        self.assertEqual(research.brand("www.shop.co.uk"), "shop")
        self.assertEqual(research.brand("shop.*"), "shop")
        self.assertEqual(research.brand("a.b.shop.com"), "shop")

    def test_normalise_site(self):
        self.assertEqual(research.normalise_site("www.Shop.com"), "shop.com")
        self.assertEqual(research.normalise_site("www.shop."), "shop.*")
        self.assertEqual(research.normalise_site("*.shop.com"), "shop.com")
        self.assertIsNone(research.normalise_site("com"))
        self.assertIsNone(research.normalise_site("we ird.com"))

    def test_expand(self):
        self.assertEqual(research.expand("abc"), {"abc"})
        self.assertEqual(research.expand("ab?"), {"a", "ab"})
        self.assertEqual(research.expand("x(?:id|ref)"), {"xid", "xref"})
        self.assertEqual(research.expand("p[fd]_x"), {"pf_x", "pd_x"})
        self.assertEqual(research.expand("a\\.b"), {"a.b"})
        self.assertIsNone(research.expand("a.*"))
        self.assertIsNone(research.expand("[a-z]+"))
        self.assertIsNone(research.expand("\\d"))
        self.assertIsNone(research.expand("(unclosed"))
        self.assertIsNone(research.expand("(a|b)(c|d)(e|f)(g|h)(i|j)(k|l)", limit=32))

    def test_clearurls_param(self):
        self.assertEqual(research.clearurls_param("(?:%3F)?zz_click"), ("param", {"zz_click"}))
        self.assertEqual(research.clearurls_param("shop_sess[a-z]*"), ("prefix", {"shop_sess"}))
        self.assertEqual(research.clearurls_param("[^a-z]weird")[1], None)

    def test_clearurls_sites(self):
        sub = "^https?:\\/\\/(?:[a-z0-9-]+\\.)*?"
        self.assertEqual(research.clearurls_sites(".*"), [None])
        self.assertEqual(research.clearurls_sites(sub + "shop\\.com"), ["shop.com"])
        self.assertEqual(research.clearurls_sites(sub + "shop(?:\\.[a-z]{2,}){1,}"), ["shop.*"])
        self.assertEqual(research.clearurls_sites(sub + "(a\\.test|b\\.test)"), ["a.test", "b.test"])
        self.assertEqual(research.clearurls_sites(sub + "shop\\.com\\/s\\?"), ["shop.com"])
        self.assertEqual(research.clearurls_sites(sub + "shop.com"), ["shop.com"])
        self.assertIsNone(research.clearurls_sites("^https?:\\/\\/[a-z]+\\d\\.example\\.org"))
        self.assertIsNone(research.clearurls_sites("no scheme here"))

    def test_filter_param(self):
        self.assertEqual(research.filter_param("zz"), ("param", "zz"))
        self.assertEqual(research.filter_param("amp;zz"), ("param", "zz"))
        self.assertEqual(research.filter_param("/^zz_/"), ("prefix", "zz_"))
        self.assertEqual(research.filter_param("/^zz=/"), ("param", "zz"))
        self.assertIsNone(research.filter_param("/(a|b)\\d{2,}/"))

    def test_split_options_keeps_regex_commas(self):
        self.assertEqual(research.split_options("doc,removeparam=/a{1,2}/,domain=x.com"),
                         ["doc", "removeparam=/a{1,2}/", "domain=x.com"])


    def test_targets_only_match_a_list_site_inside_them(self):
        cases = {"clean": [{"source": "Planner", "input": "", "expected": "https://planner.bigco.example/e?x=1"},
                           {"source": "Shop", "input": "https://bigco.example/url?q=x", "expected": "https://shopco.com/i/1"}]}
        targets = {"targets": [{"name": "Planner", "sources": ["Planner"]}, {"name": "Shop", "sources": ["Shop"]}]}
        catalog = research.Catalog(json.loads((FIXTURES / "rules.json").read_text(encoding="utf-8")), cases, targets)
        # Search params on bigco.example aren't the planner's, and a wrapper isn't where Shop lives.
        self.assertEqual(catalog.targets_for(["bigco.example"]), [])
        self.assertEqual(catalog.targets_for(["planner.bigco.example"]), ["Planner"])
        self.assertEqual(catalog.targets_for(["shopco.*"]), ["Shop"])
        self.assertEqual(catalog.targets_for(["m.shopco.com"]), ["Shop"])

    def test_a_list_prefix_lint_covers_with_an_underscore(self):
        catalog = research.Catalog(json.loads((FIXTURES / "rules.json").read_text(encoding="utf-8")))
        self.assertTrue(catalog.strips_globally("prefix", "utm"))
        self.assertFalse(catalog.strips_globally("prefix", "ut"))

    def test_downloads_stop_at_the_deadline(self):
        with self.assertRaisesRegex(RuntimeError, "ran out of time"):
            research.fetch("http://127.0.0.1:9/", 5, research.time.monotonic() - 1)


class ParserTests(unittest.TestCase):
    def test_filter_list(self):
        data = research.parse_filter((FIXTURES / "adguard.txt").read_bytes())
        self.assertIn(("param", "zz_click", None), data.params)
        self.assertIn(("param", "zz_global", None), data.params)
        self.assertIn(("prefix", "zz_rx_", None), data.params)
        self.assertIn(("param", "zz_exact", None), data.params)
        self.assertIn(("param", "shop_trk", "exampleshop.com"), data.params)
        self.assertIn(("param", "vs_share", "videosite.test"), data.params)
        self.assertIn(("param", "vs_extra", "videosite.test"), data.params)
        self.assertIn(("param", "site_only", "newsy.example"), data.params)
        self.assertNotIn(("param", "site_only", "sub.newsy.example"), data.params)
        self.assertEqual(data.regex, 1)
        # Exceptions are kept apart: they're where stripping a param breaks a site.
        self.assertEqual(data.exempt, {("shop_trk", "exampleshop.com"), ("vs_share", "videosite.test")})
        # The remove-everything rule, the broken line and the wildcard host.
        self.assertEqual(data.other, 3)

    def test_ublock_list(self):
        data = research.parse_filter((FIXTURES / "ublock.txt").read_bytes())
        self.assertIn(("param", "vs_share", "vid.example"), data.params)
        self.assertIn(("param", "shop_sess", "exampleshop.*"), data.params)
        self.assertEqual(data.redirects, {"exampleshop.com", "jump.example"})

    def test_clearurls(self):
        data, unmapped = research.parse_clearurls((FIXTURES / "clearurls.json").read_bytes())
        self.assertEqual(sorted(unmapped), ["unreadable", "x` @someone `"])
        self.assertIn(("param", "zz_click", None), data.params)
        self.assertIn(("param", "zz_mailref", None), data.params)
        self.assertIn(("prefix", "shop_sess", "exampleshop.*"), data.params)
        self.assertIn(("param", "vs_share", "vid.example"), data.params)
        self.assertIn(("param", "cl_id", "careless.example"), data.params)
        self.assertFalse(any(p[1] in ("never_seen", "selftest_param") for p in data.params))
        self.assertEqual(data.referral, {("zz_partner", None)})
        self.assertEqual(data.redirects, {"exampleshop.*"})
        self.assertEqual(data.regex, 1)

    def test_cut_short_filter_lists_are_rejected(self):
        body = "! Title: Fixture\n$removeparam=zz_one\n$removeparam=zz_two"
        digest = research.base64.b64encode(research.hashlib.md5(body.encode()).digest()).decode().rstrip("=")
        whole = body.replace("! Title: Fixture\n", f"! Title: Fixture\n! Checksum: {digest}\n")
        research.verify_filter_text("u", whole.encode())
        with self.assertRaises(RuntimeError):
            research.verify_filter_text("u", whole[:-4].encode())
        research.verify_filter_text("u", b"$removeparam=zz\n")
        with self.assertRaises(RuntimeError):
            research.verify_filter_text("u", b"$removeparam=z")

    def test_bad_input_does_not_crash(self):
        data = research.parse_filter(b"\xff\xfe$removeparam=\n||\n$$$removeparam\n||x^$removeparam=/unclosed\n")
        self.assertEqual(data.plain, 0)


class ReportTests(unittest.TestCase):
    def test_report(self):
        code, report = run(FIXTURES)
        self.assertEqual(code, 0)
        self.assertIn("This report never adds rules", report)
        self.assertIn("Nothing comes from Lint's users", report)

        everywhere = section(report, "Params stripped on every site")
        self.assertIn("| `zz_click` | 4: AdGuard URL Tracking, ClearURLs, Firefox query stripping, uBlock Origin privacy", everywhere)
        self.assertIn("`zz_mailref`", everywhere)
        self.assertIn("`zz_global`", everywhere)
        self.assertNotIn("zz_rx_", everywhere)       # one list only
        self.assertNotIn("fixture_known", report)    # Lint already strips it
        self.assertNotIn("`zz_mailid` | 2", everywhere)  # neverStrip

        site = section(report, "Site params flagged")
        # videosite.test is in Lint's Video Site entry; vid.example isn't, so it's its own row.
        # A list's exception for the site is noted next to the lead.
        self.assertIn("| `vs_share` | `videosite.test` | 3: AdGuard URL Tracking, ClearURLs, uBlock Origin privacy | 1 "
                      "| Video Site | AdGuard URL Tracking exempts it on `videosite.test` |", site)
        self.assertIn("| `vs_share` | `vid.example` | 2: ClearURLs, uBlock Origin privacy | - | - | - |", site)
        self.assertNotIn("shop_trk", report)         # Lint strips it on exampleshop.*

        single = section(report, "Target sites")
        self.assertIn("`shop_sess*`", single)
        self.assertIn("`vs_extra`", single)
        self.assertNotIn("cl_id", single)            # not a target

        redirects = section(report, "Redirect links")
        self.assertIn("`exampleshop`", redirects)
        self.assertNotIn("jump", redirects)          # one list and not a target

        kept = section(report, "Kept on purpose")
        self.assertIn("`zz_mailid`", kept)
        self.assertIn("| `keepme` | `exampleshop.*`, `exampleshop.com` | 2: AdGuard URL Tracking, ClearURLs | kept in the Example Shop link case |", kept)
        self.assertIn("`zz_partner`", kept)
        self.assertIn("| `shop_aff` | `exampleshop.com` | 1: AdGuard URL Tracking | affiliate ID (Example Shop affiliates, #28) |", kept)
        self.assertIn("| `shop_kw` | `exampleshop.com` | 1: AdGuard URL Tracking | Lint strips it only on some pages (Example Shop items: `/item/*/**`) |", kept)
        self.assertNotIn("utm", report)              # Lint strips utm_
        self.assertIn("`unreadable`", report)
        # A provider name that would end the code span and @-mention someone isn't shown, and no
        # @ anywhere in the report can mention anyone.
        self.assertNotIn("someone", report)
        self.assertNotRegex(report, "@(?!\u2060)")

    def test_failed_source_is_reported_not_fatal(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("clearurls.json", "adguard.txt", "tranco.csv"):
                shutil.copy(FIXTURES / name, tmp)
            code, report = run(Path(tmp))
        self.assertEqual(code, 0)
        self.assertRegex(report, r"\| \[uBlock Origin privacy\]\([^)]*\) \| GPL-3.0 \| \*\*failed\*\*")
        self.assertRegex(report, r"\| \[Firefox query stripping\]\([^)]*\) \| MPL-2.0 \| \*\*failed\*\*")

    def test_no_lists_at_all_exits_non_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = run(Path(tmp))
        self.assertEqual(code, 2)
        self.assertEqual(report, "")

    def test_report_is_capped(self):
        code, report = run(FIXTURES, "--max-chars", "3000", "--limit", "1")
        self.assertEqual(code, 0)
        self.assertLessEqual(len(report), 3000)
        # Cut at a line break, so no table row or code span is left half open.
        body = report.split("\n\n_Report cut short")[0]
        self.assertTrue(all(line.endswith("|") for line in body.splitlines() if line.startswith("|")))

    def test_mentions_in_status_lines_are_defused(self):
        args = research.argparse.Namespace(min_lists=2, date="2026-01-01", limit=5, max_chars=100000)
        catalog = research.Catalog(json.loads((FIXTURES / "rules.json").read_text(encoding="utf-8")))
        report = research.build(["| x | y | **failed**: server said @someone @org/team | - | - | - |"],
                                {"Fixture": research.ListData()}, catalog, {}, args, [])
        self.assertIn("@\u2060someone", report)
        self.assertNotRegex(report, "@(?!\u2060)")

    def test_runs_against_the_real_catalog(self):
        """The real rules.json, link-cases.json and targets.json load and compare without errors."""
        catalog = research.Catalog(json.loads(research.RULES.read_text(encoding="utf-8")),
                                   json.loads(research.CASES.read_text(encoding="utf-8")),
                                   json.loads(research.TARGETS.read_text(encoding="utf-8")))
        data = research.parse_filter((FIXTURES / "adguard.txt").read_bytes())
        tables = research.compare({"Fixture": data}, catalog, {}, min_lists=1)
        self.assertTrue(tables["global"])
        self.assertTrue(catalog.strips_on("param", "fbclid", "anything.example"))


if __name__ == "__main__":
    unittest.main()
