# Config layers

Kernel configuration is assembled from ordered layers. Later layers win.

| # | Layer | Source | Scope |
| --- | --- | --- | --- |
| 1 | `kernel_linux_config/linux-<ver>/base_defconfig` | OpenHarmony repo | OHOS hardening baseline |
| 2 | `kernel_linux_config/linux-<ver>/type/<type>_defconfig` | OpenHarmony repo | `standard` or `small` system |
| 2b | `kernel_linux_config/linux-<ver>/<board>/arch/<arch>_defconfig` | OpenHarmony repo | **complete** board config; supersedes 1 and 2 |
| 3 | `arch/<arch>/configs/defconfig` | kernel source tree | fallback only, see below |
| 4 | `configs/base/<arch>/*.config` | this repo | optional arch-wide deltas |
| 5 | `configs/lanes/<overlay>/*.config` | this repo | optional per-lane deltas |
| 6 | `--config PATH` | ad hoc | one-off, not persisted |
| 7 | `make olddefconfig` | kernel | re-derives symbol dependencies |

Files inside a layer apply in `sort` order, so numeric prefixes are load-bearing.

## Why layers 1–2 are not optional

It is tempting to build straight from the in-tree
`arch/<arch>/configs/defconfig` and treat the OpenHarmony configuration as
incidental. Measured on `kernel_linux_6.6 @ OpenHarmony-7.0-Release`
(commit `f4b61510`):

| set | CONFIG symbols |
| --- | --- |
| in-tree `arch/arm64/configs/defconfig` | 1579 |
| `base_defconfig` | 43 |
| `type/standard_defconfig` | 755 |
| union of the two config-repo layers | 798 |
| of those union, present in the in-tree defconfig | **110 (13 %)** |

652 symbols that OpenHarmony configures are absent from the in-tree defconfig,
including `CONFIG_ACCESS_TOKENID`, `CONFIG_ANDROID_BINDER_IPC` and the
`CONFIG_ANDROID` family. A kernel built from the in-tree defconfig is a
mainline kernel, not an OpenHarmony kernel.

`ohos-kb` therefore fetches `kernel_linux_config` for the lane's OpenHarmony
branch and logs which layer supplied the base. If it has to fall back to the
in-tree defconfig it says so loudly, and
`ci/kernel-config-check.yml` fails the build when `CONFIG_ACCESS_TOKENID` or
`CONFIG_ANDROID_BINDER_IPC` are missing from the resolved configuration.

## The two config shapes

`kernel_linux_config` mixes both conventions, and both are handled:

* **fragments** — `base_defconfig` (99 lines) and `type/*_defconfig`
  (~1248 lines) are hand-written partial configs, merged with the kernel's own
  `scripts/kconfig/merge_config.sh`.
* **complete configs** — `<board>/arch/<arch>_defconfig` is a full generated
  `.config` (~6193 lines for `rk3568`), carrying
  `# Automatically generated file; DO NOT EDIT.` When a board layer is
  selected and such a file exists, it replaces layers 1 and 2 entirely.

`config_is_full()` distinguishes them by that banner and by size.

## What belongs in `configs/` here

Very little. The OpenHarmony configuration is authoritative; anything this
repository adds is a **delta**, and a delta that restates an OpenHarmony
default will silently rot as OpenHarmony moves.

So `configs/base/` and `configs/lanes/` are intentionally sparse. Add a
fragment only when you are deliberately changing behaviour, and say why in a
comment at the top of the file. Board-specific options belong in a board lane,
never in `configs/base/<arch>/` — a base layer that hard-codes one SoC's
peripherals breaks every other board.

Currently no base fragments are shipped. The lane directories exist so that
`ohos-kb` finds an override point, and so the test suite can assert that every
lane in the matrix has one.

## Verify

```bash
./ohos-kb show ohos-7.0-6.6      # what this lane resolves to
./ohos-kb config ohos-7.0-6.6    # generate .config, prints the base layer used
./ohos-kb config ohos-7.0-6.6 --no-ohos-config   # force the fallback, for comparison
```
