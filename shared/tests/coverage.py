#!/usr/bin/env python3
"""Summarises shared/tests/link-cases.json: cases per category and per source.

Once the 1.0 target list of share sources exists, this is where coverage against it (sources
with no cases yet) gets reported.
"""
import json
from collections import Counter, defaultdict
from pathlib import Path

CASES = Path(__file__).with_name("link-cases.json")


def main() -> None:
    data = json.loads(CASES.read_text(encoding="utf-8"))
    clean = data["clean"]

    by_category = Counter(case["category"] for case in clean)
    sources = defaultdict(set)
    for case in clean:
        sources[case["category"]].add(case["source"])

    print(f"{len(clean)} clean cases, {len(data['shortLinks'])} short-link cases\n")
    print(f"{'Category':<22}{'Cases':>6}  Sources")
    for category, count in sorted(by_category.items(), key=lambda item: (-item[1], item[0])):
        print(f"{category:<22}{count:>6}  {', '.join(sorted(sources[category]))}")

    oldest = min(clean, key=lambda case: case["verified"])
    print(f"\nOldest verification: {oldest['verified']} ({oldest['source']})")


if __name__ == "__main__":
    main()
