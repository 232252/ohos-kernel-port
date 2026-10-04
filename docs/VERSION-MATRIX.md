# Version matrix

SPDX-License-Identifier: GPL-2.0

Every lane in `data/ohos-kernel-lanes.tsv`, and how each was verified. This file
is generated from that TSV; if the two disagree, the TSV is the source of truth
and this file is stale.

## How the versions were verified

Kernel versions were **read out of each remote's own `Makefile`**, never assumed
from a branch name. Two methods were used:

* `git fetch --depth 1 --filter=blob:none` followed by `git show FETCH_HEAD:Makefile`
  (offline, authoritative, used during construction)
* `https://api.gitcode.com/api/v5/repos/openharmony/<repo>/contents/Makefile?ref=<branch>`
  (used by `ohos-kb verify`, so the matrix can be re-checked without cloning)

Both read `VERSION`, `PATCHLEVEL` and `SUBLEVEL`. For example,
`kernel_linux_6.6 @ OpenHarmony-7.0-Release` resolves to `6.6.101`.

The `upstream-*` lanes deliberately declare a rolling series such as `6.18.y`
rather than a point release, because those repositories track a moving branch.
`ohos-kb` reports drift for them but does not warn.

## The headline fact

**Every OpenHarmony branch from 6.0 onwards carries Linux 6.6.101 in
`kernel_linux_6.6`.** This was checked across `OpenHarmony-6.0-Release`,
`OpenHarmony-6.1-LTS`, `OpenHarmony-6.1-Release`, `OpenHarmony-7.0-Beta1` and
`OpenHarmony-7.0-Release`. The `6.6.101` line is stable across those branches,
so a lane for any of them produces the same kernel version.

OpenHarmony publishes only these kernel repositories:

| repository | kernel | notes |
| --- | --- | --- |
| `kernel_linux_6.6` | 6.6.101 | current line |
| `kernel_linux_5.10` | 5.10.210 | current LTS line |
| `kernel_linux_4.19` | 4.19.155 | last touched at `OpenHarmony-4.0-Beta1` |
| `kernel_linux` | 4.19.155 | last touched at `OpenHarmony-2.2-Beta2` |

There is no OpenHarmony repository for 5.15, 6.1, 6.12 or 6.18. The `upstream-*`
lanes exist to carry ophub's version breadth forward over the OpenHarmony
configuration; they are marked `experimental` because no OpenHarmony release has
ever been validated against them.

## Primary lanes

| lane | source | repository | OpenHarmony branch | kernel | config overlay |
| --- | --- | --- | --- | --- | --- |
| `ohos-7.0-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-7.0-Release` | **6.6.101** | `ohos-6.6` |
| `ohos-7.0-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-7.0-Release` | **5.10.210** | `ohos-5.10` |

## Stable lanes

| lane | source | repository | OpenHarmony branch | kernel | config overlay |
| --- | --- | --- | --- | --- | --- |
| `ohos-7.0b-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-7.0-Beta1` | **6.6.101** | `ohos-6.6` |
| `ohos-6.1-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-6.1-Release` | **6.6.101** | `ohos-6.6` |
| `ohos-6.1lts-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-6.1-LTS` | **6.6.101** | `ohos-6.6` |
| `ohos-6.0-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-6.0-Release` | **6.6.101** | `ohos-6.6` |
| `ohos-6.0b-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-6.0-Beta1` | **6.6.89** | `ohos-6.6` |
| `ohos-5.1-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-5.1.0-Release` | **6.6.89** | `ohos-6.6` |
| `ohos-7.0b-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-7.0-Beta1` | **5.10.210** | `ohos-5.10` |
| `ohos-6.1-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-6.1-Release` | **5.10.210** | `ohos-5.10` |
| `ohos-6.1lts-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-6.1-LTS` | **5.10.210** | `ohos-5.10` |
| `ohos-6.0-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-6.0-Release` | **5.10.210** | `ohos-5.10` |
| `ohos-5.1-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-5.1.0-Release` | **5.10.210** | `ohos-5.10` |

## Legacy lanes

| lane | source | repository | OpenHarmony branch | kernel | config overlay |
| --- | --- | --- | --- | --- | --- |
| `ohos-5.0-6.6` | ohos | [`kernel_linux_6.6`](https://gitcode.com/openharmony/kernel_linux_6.6) | `OpenHarmony-5.0.0-Release` | **6.6.22** | `ohos-6.6` |
| `ohos-5.0-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-5.0.0-Release` | **5.10.208** | `ohos-5.10` |
| `ohos-4.1-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-4.1-Release` | **5.10.184** | `ohos-5.10` |
| `ohos-4.0-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-4.0-Release` | **5.10.165** | `ohos-5.10` |
| `ohos-3.2-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-3.2-Release` | **5.10.97** | `ohos-5.10` |
| `ohos-3.1-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-3.1-Release` | **5.10.79** | `ohos-5.10` |
| `ohos-3.0-5.10` | ohos | [`kernel_linux_5.10`](https://gitcode.com/openharmony/kernel_linux_5.10) | `OpenHarmony-3.0-LTS` | **5.10.57** | `ohos-5.10` |
| `ohos-4.0b1-4.19` | ohos | [`kernel_linux_4.19`](https://gitcode.com/openharmony/kernel_linux_4.19) | `OpenHarmony-4.0-Beta1` | **4.19.155** | `ohos-4.19` |
| `ohos-2.2-4.19` | ohos | [`kernel_linux`](https://gitcode.com/openharmony/kernel_linux) | `OpenHarmony-2.2-Beta2` | **4.19.155** | `ohos-4.19` |

## Experimental lanes

| lane | source | repository | OpenHarmony branch | kernel | config overlay |
| --- | --- | --- | --- | --- | --- |
| `upstream-5.15.y` | upstream | [`linux-5.15.y`](https://gitcode.com/openharmony/linux-5.15.y) | `-` | **5.15.y** | `ohos-5.15` |
| `upstream-6.1.y` | upstream | [`linux-6.1.y`](https://gitcode.com/openharmony/linux-6.1.y) | `-` | **6.1.y** | `ohos-6.1` |
| `upstream-6.12.y` | upstream | [`linux-6.12.y`](https://gitcode.com/openharmony/linux-6.12.y) | `-` | **6.12.y** | `ohos-6.12` |
| `upstream-6.18.y` | upstream | [`linux-6.18.y`](https://gitcode.com/openharmony/linux-6.18.y) | `-` | **6.18.y** | `ohos-6.18` |
| `upstream-5.10.y-rk35xx` | upstream | [`linux-5.10.y-rk35xx`](https://gitcode.com/openharmony/linux-5.10.y-rk35xx) | `-` | **5.10.y-rk35xx** | `ohos-rk35xx` |
| `upstream-6.1.y-rockchip` | upstream | [`linux-6.1.y-rockchip`](https://gitcode.com/openharmony/linux-6.1.y-rockchip) | `-` | **6.1.y-rockchip** | `ohos-rockchip` |

## OpenHarmony kernel repositories involved

`ohos-kernel-port` consumes four of them. Only the first is the kernel itself.

| repository | role | consumed how |
| --- | --- | --- |
| `kernel_linux_6.6`, `kernel_linux_5.10`, `kernel_linux_4.19`, `kernel_linux` | kernel source | cloned at the lane's branch |
| `kernel_linux_config` | configuration | **required**; provides `base_defconfig`, `type/*_defconfig`, per-board configs |
| `kernel_linux_patches` | patch set | not applied by default; this repository's own `patches/` is used |
| `kernel_linux_build` | build system | invoked when `--packager ohos` is selected |

Board configurations present in `kernel_linux_config` at
`OpenHarmony-7.0-Release`:

| kernel | board configurations available |
| --- | --- |
| `linux-6.6` | `rk3568` (complete 6193-line config), `qemu-arm`, `qemu-arm64` |
| `linux-5.10` | `hispark_phoenix`, `hispark_taurus`, `myd_imx8mm`, `rk3399`, `rk3568`, `unionpi_tiger`, `yangfan`, `qemu` (arm, arm64, riscv64, x86_64, loongarch) |
| `linux-4.19` | `hispark_taurus` |

A lane for the 6.6 tree with `--board rk3568` therefore gets OpenHarmony's own
rk3568 configuration; any other board falls back to
`base_defconfig` + `type/<type>_defconfig` plus this repository's overlays.

## Re-checking the matrix

```bash
./ohos-kb verify              # every lane, against the network
./ohos-kb verify primary      # one lane
```

`verify` exits non-zero if any lane cannot be reached, so it is safe to use as
a scheduled alarm. It reports `ok`, `DRIFT` (the remote moved) or `FAIL`
(unreachable) per lane.
