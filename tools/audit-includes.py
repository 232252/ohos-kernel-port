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

# Trees that are host builds, not the kernel: their includes resolve against
# the host toolchain (Qt, Python, Perl) or against vendored third-party trees,
# none of which a kernel build ever needs.  Auditing them produced 1130 false
# positives, which makes an auditor worse than useless.
NOT_KERNEL_TREES = ("tools/", "scripts/", "samples/", "Documentation/",
                    "LICENSES/", "rust/", "net-next/")

# What counts as "this include will be reached by our build".
#
# Without a parsed .config, a whole-tree include audit cannot be accurate: a
# header included only from, say, arch/arm64/hyperv/mshyperv.c is absent from
# the tree and perfectly fine, because that file is only compiled under
# CONFIG_HYPERV.  Auditing the whole tree reported 158, nearly all of them like
# that — <linux/version.h> does not exist in Linux v6.6 either, and the 52
# references to it are all in files an OpenHarmony build never compiles.
#
# What is not conditional is the core: the non-uapi headers under include/ and
# the target arch.  An include there that does not resolve breaks every build,
# and that is exactly where the real problems were found:
# include/linux/mm_types.h -> <linux/xpm_types.h>
# include/linux/memcontrol.h -> <linux/memcg_policy.h>
#
# So the audit is scoped to that set, and says so in its output.  A build that
# gets past it and then fails on a conditional include is a case for a follow-up
# run with that CONFIG forced on.
def always_compiled(rel, arch):
    if rel.startswith("include/uapi/"):
        return False
    if rel.startswith("include/"):
        return True
    if rel.startswith(f"arch/{arch}/"):
        return True
    return False

# An include that looks like a kernel header.  Everything else in an audited
# file is either relative (handled separately) or a host-tool header.
KERNEL_HEADER_PREFIXES = ("linux/", "uapi/", "asm/", "asm-generic/",
                          "dt-bindings/", "sound/", "drm/", "video/",
                          "generated/", "trace/", "scsi/", "net/", "mtd/",
                          "of/", "fs/", "acpi/", "firmware/", "crypto/",
                          "math/", "kunit/")
# Headers the build itself produces; they are absent from a pristine tree by
# design and must not be reported.
# Headers the build writes into include/generated/ or
# arch/<arch>/include/generated/.  They are absent from a pristine tree by
# design and must never be reported.  Match on the path, not the basename:
# <generated/utsrelease.h> is included 42 times across the tree.
GENERATED = re.compile(
    r"^generated/"                      # autoconf.h, bounds.h, utsrelease.h, ...
    r"|asm-offsets\.h"
    r"|timeconst\.h"
    r"|utsversion?\.h"
    r"|version\.h"
    r"|sysreg-defs\.h"
    r"|cpucaps\.h"
    r"|randstruct_hash\.h"
    r"|user_constants\.h"
    r"|machtypes\.h"
    r"|compile\.h"
    r"|.*[.-]offsets\.h"                # devicetable-offsets.h and friends
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
            if not name.endswith(SOURCE_SUFFIXES):
                continue
            if rel.startswith(NOT_KERNEL_TREES):
                continue
            # vendored third-party trees inside drivers/ and sound/ ship their
            # own headers and are not part of the kernel's include graph
            if "/staging/" in rel or rel.startswith("drivers/staging/"):
                continue
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
    # The kernel's own -I order, from arch/arm64/Makefile.  The uapi entries
    # matter: <asm/siginfo.h> is not under include/asm/ at all, it resolves to
    # arch/arm64/include/uapi/asm/siginfo.h, and leaving the uapi directories
    # out produced 90-odd false "missing" headers.
    include_dirs = [
        f"arch/{arch}/include/generated",
        f"arch/{arch}/include",
        f"arch/{arch}/include/uapi",
        "include/generated",
        "include",
        "include/uapi",
    ]
    # Generated headers do not exist in a pristine tree; the build makes them.
    generated_dirs = {"include/generated", f"arch/{arch}/include/generated"}

    def resolves_angle(target, from_rel):
        """Resolve <target> the way the kernel's build would.

        The search path for a file depends on where the file lives:
          * a file under arch/<X>/ resolves asm/... against arch/<X>/include
          * everything resolves against the target arch and the top level
        Without the per-file arch directory, every non-arm64 arch header looks
        missing, which is how the first version of this reported 1586.
        """
        local_dirs = []
        parts = from_rel.split("/")
        if parts[0] == "arch" and len(parts) >= 2:
            # arch/m68k/... ; stop at the arch name, then its include dir
            arch_name = parts[1]
            if arch_name in ("arm64", "arm", "x86", "riscv", "loongarch",
                             "s390", "mips", "m68k", "powerpc", "sparc",
                             "alpha", "ia64", "parisc", "xtensa", "csky",
                             "microblaze", "nios2", "openrisc", "hexagon",
                             "arc", "um", "c6x"):
                local_dirs.append(f"arch/{arch_name}/include")
        for d in local_dirs + include_dirs:
            if d in generated_dirs:
                continue
            if os.path.normpath(os.path.join(d, target)) in files:
                return True
        return False

    missing = {}
    out_of_scope = 0
    for rel, full in sorted(sources):
        if not always_compiled(rel, arch):
            out_of_scope += 1
            continue
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        base = os.path.dirname(rel)
        for m in ANGLE_RE.finditer(text):
            target = m.group("path")
            if GENERATED.match(target):
                continue
            if target.startswith("uapi/") and target[5:] in files:
                continue
            if resolves_angle(target, rel):
                continue
            # a relative include is resolved against the including file, not
            # against the -I paths; check that before judging it missing
            if target.startswith("."):
                cand = os.path.normpath(os.path.join(base, target))
                if cand in files or (cand + ".h") in files:
                    continue
            # anything that is not shaped like a kernel header is a host-tool or
            # third-party include and is out of scope
            if not target.startswith(KERNEL_HEADER_PREFIXES):
                continue
            # asm/... is deliberately out of scope.  Resolving it faithfully
            # means modelling Linux's arch -> include/uapi/asm-generic fallback
            # chain, and getting it wrong produced ~80 false "missing" headers
            # on a tree that compiles.  Anything wrong there surfaces as a
            # compiler error naming the file, which is a perfectly good report;
            # what an audit buys us is finding the *generic* kernel headers
            # that a core file needs and that nobody shipped, which is exactly
            # the failure this project hit twice.
            if target.startswith("asm/") or target.startswith("asm-generic/"):
                continue
            # <linux/version.h> from include/uapi/ resolves against the uapi
            # search path, which this audit does not model either.
            if rel.startswith("include/uapi/"):
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
