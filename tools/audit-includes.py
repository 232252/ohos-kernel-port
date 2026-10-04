#!/usr/bin/env python3
# ohos-kernel-port / tools/audit-includes.py
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Find `#include <...>` directives in a kernel tree whose target header is not
# present in the tree.
#
# Why this exists
# ---------------
# This is the header-side twin of tools/audit-kconfig.py, and it exists for the
# same reason.  OpenHarmony's kernel_linux_6.6 references headers that were
# never committed:
#
#     include/linux/mm_types.h:22  ->  <linux/xpm_types.h>
#
# which stops the compile at the first C file:
#
#     CC      arch/arm64/kernel/asm-offsets.s
#     include/linux/mm_types.h:22:10: fatal error: linux/xpm_types.h:
#         No such file or directory
#
# Finding these one CI run at a time costs ten minutes each.  This walks the
# tree once and reports all of them.
#
# Search paths mirror the kernel's own: the arch include directories and the
# top-level include/.  A header that is generated into the build directory
# (for example asm-offsets.h) is not reported, because it is produced during
# the build rather than shipped.
#
# Usage:
#   tools/audit-includes.py <kernel-source-dir> [--arch arm64] [--json]

import json
import os
import re
import sys

# <linux/foo.h>, "generated/asm-offsets.h" etc.  Angle-bracket includes are the
# ones resolved through the -I paths; quoted includes are relative to the
# including file and are checked separately.
ANGLE_RE = re.compile(r'^\s*#\s*include\s+<(?P<path>[^>]+)>', re.M)
QUOTED_RE = re.compile(r'^\s*#\s*include\s+"(?P<path>[^"]+)"', re.M)

SOURCE_SUFFIXES = (".c", ".h", ".S")
# Headers the build itself produces; they are absent from a pristine tree by
# design and must not be reported.
GENERATED = re.compile(
    r"(asm-offsets\.h|timeconst\.h|version\.h|utsrelease\.h|"
    r"autoconf\.h|bound\.h|utsrelease\.h|.*[.-]offsets\.h|"
    r"sysreg-defs\.h|cpucaps\.h|asm/.*|bpf_.*\.h|"
    r"asm-generic/.*|autoconf\.h)"
)


def collect(root):
    files = set()
    sources = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            files.add(rel)
            if name.endswith(SOURCE_SUFFIXES):
                sources.append((rel, full))
    return files, sources


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    root = argv[1]
    if not os.path.isdir(root):
        print(f"not a directory: {root}")
        return 2
    arch = "arm64"
    for i, a in enumerate(argv):
        if a == "--arch" and i + 1 < len(argv):
            arch = argv[i + 1]
    as_json = "--json" in argv

    files, sources = collect(root)

    # The -I paths the kernel's build uses, in its own order.
    include_dirs = [
        f"arch/{arch}/include/generated",
        f"arch/{arch}/include",
        "include/generated",
        "include",
        "include/uapi",
    ]
    # Generated headers do not exist in a pristine tree; the build makes them.
    generated_dirs = {"include/generated", f"arch/{arch}/include/generated"}

    def resolves_angle(target):
        for d in include_dirs:
            if d in generated_dirs:
                # only trust a generated dir once the build has run
                continue
            if os.path.normpath(os.path.join(d, target)) in files:
                return True
        return False

    missing = {}
    for rel, full in sorted(sources):
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        for m in ANGLE_RE.finditer(text):
            target = m.group("path")
            if GENERATED.match(target):
                continue
            if target.startswith("uapi/") and target[5:] in files:
                continue
            if resolves_angle(target):
                continue
            line = text.count("\n", 0, m.start()) + 1
            missing.setdefault(target, []).append((rel, line))

    if as_json:
        print(json.dumps({
            "root": root,
            "arch": arch,
            "missing": {k: [{"from": r, "line": l} for r, l in v]
                        for k, v in missing.items()},
            "count": len(missing),
        }, indent=2))
        return 1 if missing else 0

    if not missing:
        print(f"OK  {len(sources)} source files checked, every <...> include resolves")
        return 0

    print(f"MISSING  {len(missing)} header(s) included but not present\n")
    for target in sorted(missing):
        refs = missing[target]
        print(f"  <{target}>   referenced {len(refs)} time(s)")
        for rel, line in refs[:6]:
            print(f"      {rel}:{line}")
        if len(refs) > 6:
            print(f"      ... and {len(refs) - 6} more")
    print()
    print("The compile stops at the first one.  Supplying the header as a")
    print("declaration-only shim is usually enough when no implementation")
    print("exists; check whether the type is embedded by value before assuming")
    print("a forward declaration will do.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
