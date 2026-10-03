#!/usr/bin/env python3
"""Offline structural check of Helm templates (no helm binary needed).

Catches the mistakes that most often break a chart before `helm lint` runs in CI:
unbalanced if/with/range/define ... end blocks, stray else, unbalanced parentheses or
quotes inside actions, and unknown `include` names. It does NOT replace `helm template`.
"""
import pathlib
import re
import sys

ACTION = re.compile(r"\{\{-?(.*?)-?\}\}", re.S)
OPENERS = ("if", "with", "range", "define", "block")


def check_file(path: pathlib.Path, defined: set, used: list) -> list:
    errors = []
    text = path.read_text()
    stack = []
    for m in ACTION.finditer(text):
        body = m.group(1).strip()
        line = text.count("\n", 0, m.start()) + 1
        if body.startswith("/*"):
            continue
        word = body.split(None, 1)[0] if body else ""
        if word in OPENERS:
            stack.append((word, line))
            if word == "define":
                name = re.match(r'define\s+"([^"]+)"', body)
                if name:
                    defined.add(name.group(1))
        elif word == "end":
            if not stack:
                errors.append(f"{path}:{line}: 'end' without an open block")
            else:
                stack.pop()
        elif word == "else":
            if not stack or stack[-1][0] not in ("if", "with", "range"):
                errors.append(f"{path}:{line}: 'else' outside if/with/range")
        # strip string literals before counting parentheses
        stripped = re.sub(r'"(\\.|[^"\\])*"', '""', body)
        stripped = re.sub(r"`[^`]*`", "``", stripped)
        if stripped.count('"') % 2:
            errors.append(f"{path}:{line}: unbalanced quotes in action")
        if stripped.count("(") != stripped.count(")"):
            errors.append(f"{path}:{line}: unbalanced parentheses in action: {body[:60]}")
        for inc in re.findall(r'(?:include|template)\s+"([^"]+)"', body):
            used.append((inc, path, line))
    for word, line in stack:
        errors.append(f"{path}:{line}: '{word}' block is never closed")
    return errors


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "charts/open-agentix")
    files = sorted(p for p in (root / "templates").rglob("*") if p.suffix in (".yaml", ".tpl", ".txt"))
    defined, used, errors = set(), [], []
    for f in files:
        errors += check_file(f, defined, used)
    for name, path, line in used:
        if name not in defined:
            errors.append(f"{path}:{line}: include of undefined template '{name}'")
    for e in errors:
        print(e)
    print(f"check-templates: {len(files)} files, {len(defined)} defines, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
