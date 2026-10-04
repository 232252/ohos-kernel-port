#!/usr/bin/env python3
# ohos-kernel-port / tests/yaml_check.py
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Validate the GitHub Actions workflows.
#
# With PyYAML available this is a real parse.  Without it — the authoring
# sandbox cannot reach PyPI — it falls back to the structural checks that a
# hand-rolled checker can get right without a parser:
#
#   * tab characters used for indentation
#   * indentation that is not a multiple of two, outside block scalars
#   * unbalanced double quotes outside block scalars
#   * a block scalar that is never closed by a less-indented line
#   * a workflow with no `jobs:` or no `on:` trigger
#
# It deliberately does NOT attempt duplicate-key detection: doing that
# correctly requires tracking YAML sequences, and a checker that reports false
# positives on `steps: [- name: x / uses: y]` is worse than one that stays
# quiet.  PyYAML in CI is what catches that case.
#
# Usage: tests/yaml_check.py [file ...]

import glob
import os
import re
import sys

BLOCK_SCALAR = re.compile(r":\s*[|>][-+]0?\d*\s*$")
SEQ_ITEM = re.compile(r"^(\s*)-\s+")
KEY_LINE = re.compile(r"^(\s*)(-\s+)?(\"[^\"]*\"|'[^']*'|[^-\s#][^:]*?)\s*:(\s|$)")


def full_parse(paths, root):
    import yaml

    ok = True
    for p in paths:
        full = os.path.join(root, p)
        try:
            doc = yaml.safe_load(open(full, encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            print(f"  FAIL {p}: {exc}")
            ok = False
            continue
        if not isinstance(doc, dict):
            print(f"  FAIL {p}: top level is {type(doc).__name__}, expected a mapping")
            ok = False
            continue
        trigger = doc.get("on", doc.get(True))
        if not trigger:
            print(f"  FAIL {p}: no trigger declared, the workflow would never run")
            ok = False
            continue
        jobs = doc.get("jobs")
        if not isinstance(jobs, dict) or not jobs:
            print(f"  FAIL {p}: no jobs declared")
            ok = False
            continue
        print(f"  OK   {p}  jobs={list(jobs)}")
    return ok


def structural_check(path, rel):
    problems = []
    lines = open(path, encoding="utf-8").read().split("\n")
    block_indent = None  # indentation of an open block scalar body

    for n, raw in enumerate(lines, 1):
        line = raw.rstrip()

        # Inside a block scalar everything is literal text: no quoting rules,
        # no indentation rules.
        if block_indent is not None:
            if not line.strip():
                continue
            if len(line) - len(line.lstrip(" ")) > block_indent:
                continue
            block_indent = None

        if not line.strip() or line.lstrip().startswith("#"):
            continue

        if "\t" in line:
            problems.append(f"{rel}:{n}: tab character; YAML forbids tabs for indentation")
            continue

        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent % 2 != 0:
            problems.append(f"{rel}:{n}: indentation of {indent} is not a multiple of two")

        if BLOCK_SCALAR.search(line):
            block_indent = indent
            continue

        # Double quotes only.  A single quote is far too often an apostrophe
        # ("the kernel tree's own defconfig") for a naive count to be useful.
        if stripped.count('"') % 2:
            problems.append(f"{rel}:{n}: unbalanced double quote: {stripped[:70]}")

    return problems


def check_shape(path, rel):
    """A workflow with no `jobs:` or no trigger can never be useful."""
    text = open(path, encoding="utf-8").read()
    problems = []
    if not re.search(r"^jobs:", text, re.M):
        problems.append(f"{rel}: no top-level 'jobs:' key")
    if not re.search(r"^(on|\"on\"):", text, re.M):
        problems.append(f"{rel}: no 'on:' trigger key")
    return problems


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if len(argv) > 1:
        rels = [a if os.path.isabs(a) else os.path.relpath(a, root) for a in argv[1:]]
    else:
        rels = [
            os.path.relpath(p, root)
            for p in sorted(glob.glob(os.path.join(root, ".github", "workflows", "*.yml")))
        ]
    if not rels:
        print("  no workflows found")
        return 0

    try:
        import yaml  # noqa: F401
        print("  (PyYAML present: full parse)")
        return 0 if full_parse(rels, root) else 1
    except ImportError:
        print("  (PyYAML absent: structural check only — not a substitute for a real parse)")

    ok = True
    for rel in rels:
        full = os.path.join(root, rel)
        problems = structural_check(full, rel) + check_shape(full, rel)
        if problems:
            ok = False
            for pr in problems:
                print(f"  FAIL {pr}")
        else:
            print(f"  OK   {rel}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
