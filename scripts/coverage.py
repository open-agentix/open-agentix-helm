#!/usr/bin/env python3
"""Template coverage for the chart's helm-unittest suites.

A template counts as covered when at least one suite selects it (suite `templates`, test
`template` or assertion `template`) and that selection carries at least one assertion.
Fails when fewer than --min percent (default 80) of the templates are covered.
Needs only Python 3 + PyYAML; no helm binary.
"""
import argparse
import pathlib
import sys

import yaml


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("chart", nargs="?", default="charts/open-agentix")
    ap.add_argument("--min", type=float, default=80.0)
    ap.add_argument("--markdown", help="write a Markdown report to this file")
    args = ap.parse_args()

    chart = pathlib.Path(args.chart)
    tdir = chart / "templates"
    templates = sorted(
        str(p.relative_to(tdir))
        for p in tdir.rglob("*.yaml")
        if not p.name.startswith("_")
    )
    hits = {t: 0 for t in templates}
    unknown = []

    for suite_file in sorted((chart / "tests").glob("*_test.yaml")):
        suite = yaml.safe_load(suite_file.read_text()) or {}
        suite_templates = [t.removeprefix("templates/") for t in suite.get("templates", [])]
        for test in suite.get("tests", []):
            test_templates = [test["template"].removeprefix("templates/")] if "template" in test else suite_templates
            for a in test.get("asserts", []):
                targets = [a["template"].removeprefix("templates/")] if "template" in a else test_templates
                for t in targets:
                    if t in hits:
                        hits[t] += 1
                    else:
                        unknown.append(f"{suite_file.name}: {t}")

    covered = [t for t in templates if hits[t] > 0]
    pct = 100.0 * len(covered) / len(templates) if templates else 100.0
    lines = ["| Template | Assertions | Covered |", "| --- | ---: | :---: |"]
    for t in templates:
        lines.append(f"| `{t}` | {hits[t]} | {'yes' if hits[t] else 'NO'} |")
    lines.append("")
    lines.append(f"Template coverage: {len(covered)}/{len(templates)} = {pct:.1f} % (minimum {args.min:.0f} %)")
    report = "\n".join(lines)
    print(report)
    if args.markdown:
        pathlib.Path(args.markdown).write_text("# Chart template coverage\n\n" + report + "\n")
    for u in unknown:
        print(f"WARNING: suite references a missing template: {u}")
    if unknown:
        return 1
    return 0 if pct >= args.min else 1


if __name__ == "__main__":
    sys.exit(main())
