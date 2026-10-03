#!/usr/bin/env python3
"""Generates the values table of the chart README from `# --` comments in values.yaml
(helm-docs comment format, offline, no binary needed).

  scripts/values-table.py                 print the table
  scripts/values-table.py --write FILE    replace the block between the markers in FILE
  scripts/values-table.py --check FILE    exit 1 when FILE is out of date
"""
import json
import pathlib
import re
import sys

import yaml

CHART = pathlib.Path(__file__).resolve().parent.parent / "charts" / "open-agentix"
START, END = "<!-- values-table:start -->", "<!-- values-table:end -->"
KEY = re.compile(r"^(\s*)([A-Za-z0-9_.-]+):(\s|$)")


def lookup(values, path):
    cur = values
    for p in path:
        cur = cur[p]
    return cur


def table() -> str:
    text = (CHART / "values.yaml").read_text()
    values = yaml.safe_load(text)
    rows, stack, desc = [], [], None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("# --"):
            desc = stripped[4:].strip()
            continue
        if desc is not None and stripped.startswith("#") and not stripped.startswith("# --"):
            desc += " " + stripped[1:].strip()
            continue
        m = KEY.match(line)
        if not m or stripped.startswith("-"):
            if not stripped.startswith("#"):
                desc = None if stripped else desc
            continue
        indent, key = len(m.group(1)), m.group(2)
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, key))
        if desc is not None:
            path = [k for _, k in stack]
            try:
                default = lookup(values, path)
            except (KeyError, TypeError):
                desc = None
                continue
            dtype = {dict: "object", list: "list", bool: "bool", int: "int", float: "float",
                     str: "string", type(None): "null"}[type(default)]
            shown = json.dumps(default, separators=(", ", ": "))
            if len(shown) > 80:
                shown = shown[:77] + "..."
            shown = shown.replace("|", "\\|")
            cell = desc.replace("|", "\\|")
            rows.append(f"| `{'.'.join(path)}` | {dtype} | `{shown}` | {cell} |")
            desc = None
    head = ["| Key | Type | Default | Description |", "| --- | --- | --- | --- |"]
    return "\n".join(head + rows)


def main(argv) -> int:
    t = table()
    if not argv:
        print(t)
        return 0
    mode, target = argv[0], pathlib.Path(argv[1])
    doc = target.read_text()
    i, j = doc.index(START) + len(START), doc.index(END)
    new = doc[:i] + "\n" + t + "\n" + doc[j:]
    if mode == "--write":
        target.write_text(new)
        return 0
    if new != doc:
        print(f"{target} values table is out of date: run scripts/values-table.py --write {target}")
        return 1
    print(f"{target} values table is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
