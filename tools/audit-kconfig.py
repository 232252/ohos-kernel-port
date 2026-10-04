#!/usr/bin/env python3
# ohos-kernel-port / tools/audit-kconfig.py
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Find Kconfig `source` statements in a kernel tree whose target file does not
# exist.
#
# Why this exists
# ---------------
# OpenHarmony's kernel_linux_6.6 sources several Kconfig files that are not
# tracked in the repository.  kconfig stops at the first one, so `make
# olddefconfig` reports exactly one missing file per run:
#
#     fs/Kconfig:54: can't open file "fs/proc/memory_security/Kconfig"
#     ... fixed, rerun ...
#     security/Kconfig:228: can't open file "security/xpm/Kconfig"
#     ... fixed, rerun ...
#
# Finding them one at a time through CI costs ten minutes each.  This walks the
# whole tree once and reports all of them.
#
# A missing source is a hard build failure, so the exit status is non-zero when
# any is found; CI can gate on that.
#
# Usage:
#   tools/audit-kconfig.py <kernel-source-dir> [--json] [--quiet]

import json
import os
import re
import sys

# source, rsource, osource — the three forms kconfig accepts.
SOURCE_RE = re.compile(r'^\s*(?:o|r|)?source\s+"(?P<path>[^"]+)"', re.M)

# Kconfig files can be named Kconfig, Kconfig.* or be a directory's Kconfig.
def is_kconfig(path):
    base = os.path.basename(path)
    return base == "Kconfig" or base.startswith("Kconfig.")


def audit(root):
    """Return (dangling, checked) where dangling is a list of dicts."""
    tracked = set()
    kconfigs = []
    for dirpath, dirnames, filenames in os.walk(root):
        # .git is not part of the tree's kconfig graph
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            tracked.add(rel)
            if is_kconfig(rel):
                kconfigs.append((rel, full))

    dangling = []
    for rel, full in sorted(kconfigs):
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        for m in SOURCE_RE.finditer(text):
            target = m.group("path")
            line = text.count("\n", 0, m.start()) + 1
            if target not in tracked:
                dangling.append({
                    "from": rel,
                    "line": line,
                    "target": target,
                })
    return dangling, len(kconfigs)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    root = argv[1]
    if not os.path.isdir(root):
        print(f"not a directory: {root}")
        return 2
    as_json = "--json" in argv
    quiet = "--quiet" in argv

    dangling, nkconfig = audit(root)

    if as_json:
        print(json.dumps({
            "root": root,
            "kconfig_files": nkconfig,
            "dangling": dangling,
            "count": len(dangling),
        }, indent=2))
        return 1 if dangling else 0

    if not dangling:
        print(f"OK  {nkconfig} Kconfig files checked, every source resolves")
        return 0

    print(f"DANGLING  {len(dangling)} unresolved Kconfig source(s) in {nkconfig} Kconfig files\n")
    by_dir = {}
    for d in dangling:
        by_dir.setdefault(os.path.dirname(d["from"]) or ".", []).append(d)
    for directory in sorted(by_dir):
        print(f"  {directory}/")
        for d in by_dir[directory]:
            print(f"    {d['from']}:{d['line']}  ->  {d['target']}")
        print()
    print("kbuild cannot start until each target exists or its source line is removed.")
    print("Check whether a configuration sets a symbol from the missing file before")
    print("deleting the line: a board defconfig that asks for the symbol would")
    print("otherwise lose it silently.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
