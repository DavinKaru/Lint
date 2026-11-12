#!/usr/bin/env python3
"""Reports progress towards 1.0: which target share sources have test cases, and how many of
those cases are verified against a real share.

    python3 shared/tests/coverage.py            # summary
    python3 shared/tests/coverage.py --missing  # also list targets with no cases yet, and ⚠
                                                #   targets with no case verified from a real share

Reads link-cases.json (the shared test set) and targets.json (the 1.0 target list).
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).parent


def main() -> None:
    cases = json.loads((HERE / "link-cases.json").read_text(encoding="utf-8"))
    targets = json.loads((HERE / "targets.json").read_text(encoding="utf-8"))["targets"]
    clean = cases["clean"]

    by_source = defaultdict(list)
    for case in clean:
        by_source[case["source"]].append(case)

    rows = defaultdict(lambda: {"total": 0, "covered": 0, "verified": 0})
    missing = []
    risky_unverified = []
    for target in targets:
        own = [c for source in target["sources"] or [target["name"]] for c in by_source.get(source, [])]
        row = rows[target["category"] or "Uncategorised"]
        row["total"] += 1
        if own:
            row["covered"] += 1
            if any(c.get("verified") for c in own):
                row["verified"] += 1
            elif target["breakRisk"]:
                risky_unverified.append(target)
        else:
            missing.append(target)

    total = sum(r["total"] for r in rows.values())
    covered = sum(r["covered"] for r in rows.values())
    verified = sum(r["verified"] for r in rows.values())
    unverified_cases = sum(1 for c in clean if not c.get("verified"))

    print(f"Target sources: {covered}/{total} have test cases ({covered * 100 // total}%), "
          f"{verified} verified against a real share ({verified * 100 // total}%). 1.0 needs 95%.")
    print(f"{len(risky_unverified)} of the covered targets are ⚠ (some params make the link work) and have "
          f"no case verified from a real share yet (--missing lists them).")
    print(f"Test set: {len(clean)} clean cases ({unverified_cases} not yet verified from a phone), "
          f"{len(cases.get('unwrap', []))} unwrap cases, {len(cases['shortLinks'])} short-link cases.\n")
    print(f"{'Category':<22}{'Targets':>8}{'Covered':>9}{'Verified':>10}")
    for category, row in sorted(rows.items(), key=lambda item: item[0]):
        print(f"{category:<22}{row['total']:>8}{row['covered']:>9}{row['verified']:>10}")

    if "--missing" in sys.argv:
        print("\n⚠ with cases but no real share yet:")
        for target in sorted(risky_unverified, key=lambda t: (t["category"] or "", t["name"])):
            print(f"  {target['category'] or 'Uncategorised'}: {target['name']}")
        print("\nNo cases yet (first batch first):")
        for target in sorted(missing, key=lambda t: (t["priority"] != "first", t["category"] or "", t["name"])):
            flag = " ⚠" if target["breakRisk"] else ""
            print(f"  [{target['priority']}] {target['category'] or 'Uncategorised'}: {target['name']}{flag}")


if __name__ == "__main__":
    main()
