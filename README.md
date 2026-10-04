# ohos-kernel-port

[![CI — config check](https://github.com/232252/ohos-kernel-port/actions/workflows/kernel-config-check.yml/badge.svg)](https://github.com/232252/ohos-kernel-port/actions/workflows/kernel-config-check.yml)
[![CI — build](https://github.com/232252/ohos-kernel-port/actions/workflows/build-kernel.yml/badge.svg)](https://github.com/232252/ohos-kernel-port/actions/workflows/build-kernel.yml)
[![License: GPL-2.0-only](https://img.shields.io/badge/license-GPL--2.0--only-blue.svg)](LICENSE)

[中文说明](README.cn.md)

Build OpenHarmony kernels with the ergonomics of the [ophub](https://github.com/ophub)
multi-kernel system: a named **lane** per buildable combination, layered
configuration, ordered patch application, and a CI matrix — pointed at
OpenHarmony instead of Armbian and OpenWrt.

**Primary target: `OpenHarmony-7.0-Release` with Linux 6.6.101.**

---

## What this is

ophub solved the problem of building one kernel for many cheap ARM boards
across three userlands. Its problem is different: OpenHarmony already has a
kernel, a configuration repository, a patch repository and a build system, and
they are not connected in a way that a third party can drive from outside.

`ohos-kernel-port` is the missing adapter. It keeps ophub's structure and
replaces its sources:

| ophub | ohos-kernel-port |
| --- | --- |
| `unifreq/linux-<series>.y`, `ophub/linux-<series>.y` | `gitcode.com/openharmony/kernel_linux_<ver>` on the matching `OpenHarmony-<x.y>-Release` branch |
| `kernel-config/<board>/config-<ver>` | `kernel_linux_config` — `base_defconfig`, `type/{small,standard}_defconfig`, per-board configs |
| `kernel-patch/{common-kernel-patches,linux-<series>.y}` | same layout, so existing patch collections drop in unchanged |
| `amlogic-s9xxx-armbian/compile-kernel/` | `ohos-kb` + `scripts/lib/*` |
| `.deb` packages for a Debian userland | OpenHarmony boot artifacts |
| version stamped on every build | version stamping **off** by default |

## The lane matrix

`data/ohos-kernel-lanes.tsv` is the single source of truth. Every row is one
buildable combination, and every row's kernel version was read out of the
remote's own `Makefile` rather than assumed.

```bash
./ohos-kb list-lanes
```

```
LANE                     SOURCE    REPO                OPENHARMONY BRANCH         KVER        STATUS
ohos-7.0-6.6             ohos      kernel_linux_6.6    OpenHarmony-7.0-Release    6.6.101     primary
ohos-7.0-5.10            ohos      kernel_linux_5.10   OpenHarmony-7.0-Release    5.10.210    primary
ohos-6.1-6.6             ohos      kernel_linux_6.6    OpenHarmony-6.1-Release    6.6.101     stable
ohos-6.0-6.6             ohos      kernel_linux_6.6    OpenHarmony-6.0-Release    6.6.101     stable
ohos-5.0-6.6             ohos      kernel_linux_6.6    OpenHarmony-5.0.0-Release  6.6.22      legacy
...
upstream-6.18.y          upstream  linux-6.18.y        -                          6.18.y      experimental
```

28 lanes: 22 backed by OpenHarmony kernel repositories, 6 carrying ophub's
mainline breadth forward with the OpenHarmony configuration applied on top.

`ohos-kb verify` re-reads every lane's remote `Makefile` and reports drift, so
the matrix can be checked without cloning anything.

## Usage

```bash
./ohos-kb doctor                          # what this host can build
./ohos-kb show ohos-7.0-6.6               # resolve a lane
./ohos-kb all ohos-7.0-6.6                # fetch → patch → config → build → package
./ohos-kb all primary --board rk3568      # add an OpenHarmony board layer
./ohos-kb config ohos-7.0-6.6             # configuration only
./ohos-kb verify                          # check the matrix against the remotes
./ohos-kb list-lanes --status primary
```

Run `ohos-kb help` for the full option list.

## What it does differently, and why

**The OpenHarmony configuration repository is mandatory.** Measured on
`kernel_linux_6.6 @ OpenHarmony-7.0-Release`, the in-tree
`arch/arm64/configs/defconfig` covers only **110 of the 798** symbols that
OpenHarmony's `base_defconfig` and `type/standard_defconfig` set — 13 %. The 652
missing ones include `CONFIG_ACCESS_TOKENID` and `CONFIG_ANDROID_BINDER_IPC`.
A kernel built from the in-tree defconfig is a mainline kernel. `ohos-kb`
therefore always consults `kernel_linux_config`, logs which layer supplied the
base, and warns loudly if it ever has to fall back. CI fails the build when
those symbols are absent. See [configs/README.md](configs/README.md).

**It will not fake a `boot.img`.** An OpenHarmony boot image is *not* an
Android boot image; it uses OpenHarmony's own `img_format` header format, and
that helper ships only inside closed prebuilts. Rather than hand you an
`mkbootimg` output that an OpenHarmony bootloader cannot boot, the packer
emits the raw `Image` plus a `boot-img-cmd.txt` with the exact command to
finish. See [docs/BOOT-IMAGE.md](docs/BOOT-IMAGE.md).

**Version stamping is opt-in.** ophub stamps every kernel because Armbian and
OpenWrt match on the version string. OpenHarmony does not, and an unexpected
`LOCALVERSION` is a gratuitous difference from the release a lane claims to
track. Use `--sign` if you want it.

## Status

| | |
| --- | --- |
| Lane matrix | verified against the remotes, 28 lanes |
| Self-tests | 39 passing (`tests/run-tests.sh`) |
| CI | config check, build, nightly matrix |
| Local full build | not run in the authoring sandbox (2 cores, 3 GB RAM) — CI is the reference |

The 6.6 board coverage inside OpenHarmony itself is narrow: at
`OpenHarmony-7.0-Release`, `kernel_linux_config` ships configurations for
`rk3568` and the `qemu` targets only, while the 5.10 tree covers
`rk3399`, `myd_imx8mm`, `unionpi_tiger`, `yangfan`, `hispark_*` and `qemu`.
A lane can therefore build a kernel for a board OpenHarmony has not
configured — see [docs/PORTING-NOTES.md](docs/PORTING-NOTES.md).

## Documentation

* [docs/VERSION-MATRIX.md](docs/VERSION-MATRIX.md) — every lane, with how it was verified
* [docs/PORTING-NOTES.md](docs/PORTING-NOTES.md) — what differs between ophub and OpenHarmony, and the traps
* [docs/BOOT-IMAGE.md](docs/BOOT-IMAGE.md) — the boot image format problem
* [docs/COMPLIANCE.md](docs/COMPLIANCE.md) — the GPL-2.0 obligations this project satisfies
* [configs/README.md](configs/README.md) — configuration layering

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Sign-off is required.

## Licence

GPL-2.0-only. This is not a choice — see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)
for why a derived work of ophub/kernel and the Linux kernel cannot be relicensed.

    Copyright (C) 2021 ophub contributors
    Copyright (C) 2021 https://github.com/unifreq/openwrt_packit
    Copyright (C) 2026 ohos-kernel-port contributors

`LICENSE` is the verbatim FSF GPL-2.0 text. `NOTICE` records the changes
relative to ophub and carries the trademark disclaimers.

## Trademarks

This is an independent community project with no affiliation to, endorsement
by, or sponsorship from Huawei Technologies Co., Ltd., the OpenAtom Open Source
Foundation, the OpenHarmony project, ophub, unifreq, Armbian, or the OpenWrt
Project. `OpenHarmony` and the OpenHarmony logo are trademarks of the OpenAtom
Open Source Foundation; `HarmonyOS` and `Huawei` are trademarks of Huawei
Technologies Co., Ltd.; `Armbian` and `OpenWrt` are trademarks of their
respective rights holders. All are used descriptively only. No logo or brand
identifier is reproduced here.
