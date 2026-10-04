# Porting notes

SPDX-License-Identifier: GPL-2.0

What actually differs between ophub's world and OpenHarmony's, written down so
the next person does not have to rediscover it. Everything here was measured or
read directly; the method is noted per item.

## 1. OpenHarmony is not one repository

ophub's mental model is "a kernel repo, a config repo, a patch repo, and a
build script". OpenHarmony's is similar but the pieces have different names and
one extra member.

| role | ophub | OpenHarmony |
| --- | --- | --- |
| kernel source | `unifreq/linux-<series>.y`, `ophub/linux-<series>.y` | `kernel_linux_6.6`, `kernel_linux_5.10`, `kernel_linux_4.19`, `kernel_linux` |
| configuration | `kernel-config/<board>/config-<ver>` | `kernel_linux_config` |
| patches | `kernel-patch/` | `kernel_linux_patches` |
| build engine | `amlogic-s9xxx-armbian/compile-kernel/` | `kernel_linux_build` |
| out-of-tree modules | — | `kernel_linux_common_modules` |

All are on `gitcode.com/openharmony/` and all carry
`OpenHarmony-<x.y>-Release` branches. The pitfall is that the obvious naming
guess — `kernel_linux_<major>.<minor>` — only finds four of them. Enumerating
the organisation (807 repositories) is what surfaced `kernel_linux_config`,
`kernel_linux_patches` and `kernel_linux_build` in the first place. If you are
looking for something in OpenHarmony and cannot find it, list the org; do not
conclude it does not exist.

## 2. The in-tree defconfig is not an OpenHarmony defconfig

This is the trap worth the most words, because getting it wrong produces a
kernel that builds cleanly, passes a smoke test, and is subtly wrong.

Measured on `kernel_linux_6.6 @ OpenHarmony-7.0-Release` (commit `f4b61510`):

| set | CONFIG symbols |
| --- | --- |
| in-tree `arch/arm64/configs/defconfig` | 1579 |
| `kernel_linux_config/linux-6.6/base_defconfig` | 43 |
| `kernel_linux_config/linux-6.6/type/standard_defconfig` | 755 |
| union of the config-repo layers | 798 |
| of that union, present in the in-tree defconfig | **110 (13 %)** |

652 symbols OpenHarmory configures are missing from the in-tree defconfig,
including:

* `CONFIG_ACCESS_TOKENID` — the kernel half of OpenHarmony's access-token model
* `CONFIG_ANDROID_BINDER_IPC`, `CONFIG_ANDROID_BINDER_DEVICES` — binder
* the `CONFIG_ANDROID` family

The kernel tree defines no `CONFIG_OHOS*` symbol at all, which is what makes
this so easy to get wrong: a grep for "OHOS" in the config comes back empty and
suggests the tree is not OHOS-flavoured. It *is* OHOS-flavoured — the flavour is
in the separate config repository, not in the kernel repo.

`ohos-kb` handles this by always consulting `kernel_linux_config`, logging which
layer supplied the base, and warning loudly if it falls back.
`ci/kernel-config-check.yml` asserts `CONFIG_ACCESS_TOKENID` and
`CONFIG_ANDROID_BINDER_IPC` are present, so the failure cannot pass silently.

## 3. The config repository mixes two conventions

`kernel_linux_config/linux-<ver>/` holds both fragments and complete configs:

* `base_defconfig` — 99 lines, hand-written fragment
* `type/{small,standard}_defconfig` — ~1248 lines, hand-written fragment
* `<board>/arch/<arch>_defconfig` — ~6193 lines, a **complete** generated
  `.config` whose header reads `# Automatically generated file; DO NOT EDIT.`

ophub only ever handles fragments. Treating a complete config as a fragment
merges it into something else and loses most of it. `config_is_full()` detects
the banner and the file size, and a complete board config supersedes
`base_defconfig` and `type/*_defconfig` entirely rather than layering on them.

`small` versus `standard` is the system-type split — a lightweight system for
constrained devices versus the full standard system. It selects which
`type/*_defconfig` is used, so it is a first-class lane parameter, not a detail.

## 4. 6.6 has very little board coverage

At `OpenHarmony-7.0-Release`, `kernel_linux_config/linux-6.6/` ships board
configurations for `rk3568` only, plus the `qemu-arm` and `qemu-arm64` targets.
The 5.10 tree is far richer: `rk3399`, `myd_imx8mm`, `unionpi_tiger`, `yangfan`,
`hispark_phoenix`, `hispark_taurus`, and qemu for several architectures.

Consequences:

* A 6.6 lane with `--board rk3568` gets OpenHarmony's own complete rk3568
  config. A 6.6 lane with any other `--board` falls back to
  `base_defconfig` + `type/*_defconfig` and will very likely not boot on that
  board.
* The 4.19 line stops at `OpenHarmony-4.0-Beta1`; `kernel_linux` stops at
  `OpenHarmony-2.2-Beta2`. Those lanes exist for reproducibility, not for new
  work.
* Expect the 6.6 `type/standard_defconfig` to contain options that real vendor
  hardware of that era did not enable. Treat bring-up failures as a config
  question first.

## 5. The OpenHarmony 6.6 tree cannot run kbuild on a pristine clone

This is the finding that most shaped the port, and it is not visible from the
outside.

Five Kconfig files are sourced but **not tracked in the repository**:

| referring file | line | missing target |
| --- | --- | --- |
| `fs/Kconfig` | 54 | `fs/proc/memory_security/Kconfig` |
| `fs/Kconfig` | 131 | `fs/code_sign/Kconfig` |
| `fs/Kconfig` | 133 | `fs/dec/Kconfig` |
| `security/Kconfig` | 228 | `security/xpm/Kconfig` |
| `security/Kconfig` | 230 | `security/container_escape_detection/Kconfig` |

Checked on `OpenHarmony-6.0-Release`, `OpenHarmony-6.1-Release`,
`OpenHarmony-7.0-Beta1` and `OpenHarmony-7.0-Release`: all four branches, all
five references, none of the five directories present. Upstream Linux v6.6
references none of them, so this is an OpenHarmony addition left incomplete.

The consequence is that kbuild cannot start at all:

```
$ make O=out ARCH=arm64 olddefconfig
fs/Kconfig:54: can't open file "fs/proc/memory_security/Kconfig"
make[3]: *** [scripts/kconfig/Makefile:77: olddefconfig] Error 1
```

Two Makefiles compound it, naming directories that do not exist:

```
fs/proc/Makefile:37   obj-$(CONFIG_MEMORY_SECURITY) += memory_security/
security/Makefile:7   subdir-$(CONFIG_SECURITY_CONTAINER_ESCAPE_DETECTION) += container_escape_detection
security/Makefile:27  obj-$(CONFIG_SECURITY_XPM) += xpm/
security/Makefile:29  obj-$(CONFIG_SECURITY_CONTAINER_ESCAPE_DETECTION) += container_escape_detection/
```

**Why the references cannot simply be deleted.** OpenHarmony's own
configuration depends on two of them:

* `kernel_linux_config/linux-6.6/base_defconfig:18` sets `CONFIG_SECURITY_XPM=y`
* `linux-6.6/rk3568/arch/arm64_defconfig` sets `CONFIG_SECURITY_XPM_DEBUG=y` (6162)
  and `CONFIG_MEMORY_SECURITY=y` (6174)

Removing those Kconfig files would let `olddefconfig` discard the symbols
silently, and a board configuration would quietly lose settings it asks for.

**What `patches/linux-6.6.y/010-fix-dangling-kconfig-sources.patch` does:**

1. Adds declaration-only `fs/proc/memory_security/Kconfig` and
   `security/xpm/Kconfig`, defining `MEMORY_SECURITY`, `SECURITY_XPM` and
   `SECURITY_XPM_DEBUG` so those options resolve and the existing
   configurations validate. There is no implementation in this tree to compile.
2. Removes the four `obj-`/`subdir-` lines, because the directories they name do
   not exist. Enabling the options now builds nothing extra, which is the true
   state of the tree.
3. Removes the source lines for `fs/code_sign`, `fs/dec` and
   `security/container_escape_detection`. No configuration references a symbol
   from any of them and nothing builds them, so these are dead references
   rather than missing declarations.

When OpenHarmony lands the real subsystems, drop the patch: the files and the
`obj-` lines will exist, and `ohos-kb` will report that the patch no longer
applies rather than silently mis-building.

## 5a. The same tree is also missing a header

With the Kconfig graph fixed, kconfig runs to completion — the resolved
configuration goes from 1349 lines to a full **5812** — and the compile then
stops at the first C file:

```
CC      arch/arm64/kernel/asm-offsets.s
include/linux/mm_types.h:22:10: fatal error: linux/xpm_types.h: No such file or directory
   22 | #include <linux/xpm_types.h>
```

`include/linux/xpm_types.h` is not tracked, and neither `struct xpm_region` nor
`struct cs_info` is defined anywhere in the tree. Three files include it:

* `include/linux/mm_types.h:22`
* `include/linux/hck/lite_hck_code_sign.h:9`
* `fs/verity/fsverity_private.h:15`

**This cannot be fixed by disabling the option.** The include in `mm_types.h`
is unconditional; only the uses are guarded:

```c
#include <linux/xpm_types.h>          /* line 22, unconditional */
...
#ifdef CONFIG_SECURITY_XPM
        struct xpm_region xpm_region; /* line 990 */
#endif
#ifdef CONFIG_SECURITY_CODE_SIGN
        struct cs_info pcs_info;
#endif
```

`kernel_linux_config/linux-6.6/base_defconfig:18` sets `CONFIG_SECURITY_XPM=y`,
so that branch *is* compiled and `struct xpm_region` must be a complete type
that can be embedded by value in `mm_struct`.

`patches/linux-6.6.y/020-add-missing-xpm-types-header.patch` supplies the
header with declaration-only types. It edits **no existing file** — deliberately,
because `mm_types.h` is core and supplying a missing header is safer than
editing one. The field layouts are placeholders, not the real XPM ABI: there is
no xpm implementation in this tree to have an ABI.

Worth noting: `include/linux/hck/lite_hck_xpm.h` **is** present and carries
"Copyright (c) 2023 Huawei Device Co., Ltd." So the feature is partially
landed. That is the same pattern as the Kconfig sources and the `obj-` hooks —
the glue was committed and the implementation was not.

`tools/audit-includes.py` is the header-side twin of the Kconfig auditor: it
resolves every `#include <...>` against the kernel's own include paths and
reports all of them at once. `ci/kernel-config-check.yml` runs both, so
either class of hole fails the fast job rather than the hour-long one.

**How to find these yourself, in one pass.** kconfig stops at the first
unresolved source, so a build reveals these one at a time — at roughly ten
minutes per CI run, which is how three of them were found and the fourth and
fifth only later. `tools/audit-kconfig.py` walks every Kconfig file once,
resolves each `source`/`rsource`/`osource` target against the tracked file set,
and reports all of them grouped by directory. It exits non-zero when it finds
any, and `ci/kernel-config-check.yml` runs it, so an inconsistent tree now
fails the fast job instead of the hour-long one.

The general lesson: a shallow clone is what everyone uses, and a tree can be
internally inconsistent in ways that only appear when you run the build.
`ohos-kb` does not assume a fetched tree is coherent — the patch layer exists
to make it so, and the audit exists to prove it.

## 6. Version stamping should be off

ophub appends a signature to every kernel it builds — `-ophub`, `-yourname`, or
a seasonal joke. Armbian and OpenWrt select kernels by version string, so this
is load-bearing for them.

OpenHarmony does not select by version string, and a lane's whole value
proposition is that it tracks a specific release. An injected `LOCALVERSION`
makes the artifact differ from the release it claims to reproduce, for no gain.
`ohos-kb` therefore leaves it off unless you pass `--sign`.

## 7. Patching, and the 6.6.101 cliff

ophub applies patches with `common-kernel-patches/` first then the
series directory, skipping any other directory name — which is how
`deprecated-patches/` stays out of the way. `ohos-kb` keeps that contract
exactly, so an existing ophub patch collection drops into `patches/` unchanged.

The `upstream-*` lanes are where conflicts will appear: those trees move, and a
patch written against one tip may not apply to the next. `ohos-kb` uses
`git am --3way` and treats a failure as fatal rather than applying what it can
and moving on, because a half-patched kernel that compiles is the worst
possible outcome.

OpenHarmony's own `kernel_linux_patches` repository (3217 files) is *not*
applied by default. It is the project's own patch set for its own branches, and
the kernel repositories already contain its results. Applying it again would be
a double-apply. Reach for it only when reproducing an OpenHarmory CI run.

## 8. Toolchain: clang is the intended compiler

`kernel_linux_config/linux-6.6/base_defconfig` sets `CONFIG_CFI_CLANG`, which
only clang satisfies. A gcc build does not fail — gcc simply drops the option,
and you get a kernel without control-flow integrity that silently differs from
the one OpenHarmony ships.

`ohos-kb` warns about this when `--cc gcc` is used. The toolchain table in
`data/toolchains.tsv` lists prebuilt cross toolchains published by ophub with
their real SHA-256 digests, taken from the GitHub Releases API; the naming is
not what you would guess, which is why the table exists.

## 9. Patching versus the authoring sandbox

Building a 6.6 arm64 kernel needs on the order of 40 GB of disk and far more
than 3 GB of RAM. It belongs in CI. What is worth running locally is
`tests/run-tests.sh`, which covers lane resolution, URL construction, patch
ordering, config-mode detection, the compliance invariants and the CLI surface
in seconds, with no tree, no toolchain and no network.
