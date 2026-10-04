# Changelog

SPDX-License-Identifier: GPL-2.0

All notable changes to this project are recorded here, as GPL-2.0 §2(a)
evidence of what changed and when.

## [Unreleased]

### Added

- `ohos-kb`, a lane-driven build driver: `fetch`, `config`, `build`,
  `package`, `all`, `verify`, `list-lanes`, `show`, `doctor`, `clean`.
- A lane matrix (`data/ohos-kernel-lanes.tsv`) of 28 buildable combinations,
  every kernel version read out of the remote's own `Makefile`.
- `ohos-kb verify`, which re-checks the matrix against gitcode without
  cloning, and reports `ok` / `DRIFT` / `FAIL` per lane.
- Layered configuration that consumes OpenHarmony's `kernel_linux_config`,
  supporting both its hand-written fragments and its complete per-board
  configs.
- Two-tier patch application (`common-kernel-patches/` then
  `linux-<series>.y/`), compatible with ophub's existing patch collections.
- `collect_kernel_headers`, so out-of-tree modules
  (`kernel_linux_common_modules`) can be built against a produced kernel.
- CI: a configuration gate with a licence check, a matrix-drift check and a
  real build workflow, all driving `./ohos-kb` rather than duplicating its
  logic.
- `tests/run-tests.sh`, 39 assertions covering lane resolution, URL
  construction, patch ordering, config-mode detection, compliance invariants
  and the CLI surface.
- Documentation: `README.md` / `README.cn.md`, `docs/VERSION-MATRIX.md`,
  `docs/PORTING-NOTES.md`, `docs/BOOT-IMAGE.md`, `docs/COMPLIANCE.md`,
  `configs/README.md`.

### Changed relative to ophub/kernel

- Kernel sources resolve to the OpenHarmony kernel repositories on
  `gitcode.com/openharmony` at the lane's `OpenHarmony-<x.y>-Release` branch,
  instead of `unifreq/linux-<series>.y` and `ophub/linux-<series>.y`.
- Configuration comes from `kernel_linux_config` instead of
  `kernel-config/<board>/config-<version>`.
- Packaging produces OpenHarmony boot artifacts instead of Debian packages for
  an Armbian/OpenWrt userland.
- Version stamping is off by default; opt in with `--sign`.
- Clone retries follow ophub's persistence (10 attempts) because gitcode rate
  limits under CI.

### Findings recorded during the port

- The in-tree `arch/arm64/configs/defconfig` in `kernel_linux_6.6` covers only
  110 of the 798 symbols OpenHarmony's `base_defconfig` and
  `type/standard_defconfig` set (13 %). 652 are absent, including
  `CONFIG_ACCESS_TOKENID` and `CONFIG_ANDROID_BINDER_IPC`. Building from the
  in-tree defconfig yields a mainline kernel, not an OpenHarmony one.
- An OpenHarmony `boot.img` is not an Android boot image. It uses OpenHarmony's
  own `img_format` header format, and that helper ships only inside closed
  prebuilts, so a flashable image cannot be produced entirely from public
  sources. The packer reports this honestly rather than substituting an
  AOSP-format file. See `docs/BOOT-IMAGE.md`.
- OpenHarmony's kernel organisation holds 807 repositories; the kernel-related
  ones are not discoverable by guessing the `kernel_linux_<version>` naming.
