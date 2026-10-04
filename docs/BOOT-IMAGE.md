# The OpenHarmony boot image

SPDX-License-Identifier: GPL-2.0

## The problem, stated plainly

An OpenHarmony `boot.img` is **not** an Android boot image.

This is the single most misleading thing about packaging an OpenHarmony kernel
outside an OpenHarmony source tree, and it is worth being blunt about: you can
easily produce a file called `boot.img`, ship it, and have it silently fail to
boot on real hardware.

An AOSP `mkbootimg` will cheerfully emit a `boot.img` from your freshly built
`Image`. It is a valid *Android* boot image. An OpenHarmony bootloader will not
accept it, because the header layout is a different format entirely.

## What the format actually is

OpenHarmony packs boot images with a helper called `img_format`, which takes a
layout descriptor rather than a list of flags. That helper is **not part of any
public OpenHarmony repository**. The published packing tooling archive
(`packing_tool/packing_tool_libs_*.zip`) contains only Java `.jar` files — there
is no Linux `img_format` binary in it.

So there is no open, redistributable way to produce a flashable OpenHarmony
`boot.img` from outside the OpenHarmony build system. This is a licensing and
distribution reality, not a gap that more effort would close.

## What `ohos-kb` does about it

The packer resolves a backend in this order, and never pretends:

1. **`img_format` available** — via `OKCP_IMG_FORMAT`, or on `PATH`. This is
   the byte-exact path and the only one that yields a flashable OpenHarmony boot
   image. It is used, and the result is labelled as such.
2. **No `img_format`** — the raw `Image` is emitted together with
   `boot-img-cmd.txt` containing the exact command to finish the job once you
   have the tool, plus the alternative of building inside an OpenHarmony tree.
   A `boot-img.status` file records `skipped=no-img_format` so a pipeline can
   assert on it.
3. **`OKCP_BOOT_BACKEND=mkbootimg`** — an explicitly requested AOSP-format
   image is produced, written as **`boot-aosp.img`**, not `boot.img`, and
   labelled in the log. It is for bootloader bring-up and QEMU only.

A CI job that reports "produced a flashable OpenHarmony boot.img" when it
produced an AOSP one is worse than a job that reports honestly that it could not.
That is why step 3 is opt-in and never named `boot.img`.

## Getting a real `boot.img` anyway

Two supported routes.

### Use the OpenHarmony build system

Drop the built `Image` where the OpenHarmony tree expects it and let
OpenHarmony's own tooling pack it:

```bash
# inside an OpenHarmony source tree
cp <artifact>/Image kernel/linux/linux-6.6/arch/arm64/boot/Image
./build.sh --build-target kernel            # or the target your branch supports
```

This is the path `ohos-kb --packager ohos` drives, by delegating to
`kernel_linux_build/build_kernel.sh`. The output is byte-comparable with a
stock OpenHarmony build.

### Supply `img_format`

```bash
OKCP_IMG_FORMAT=/path/to/img_format ./ohos-kb package ohos-7.0-6.6
```

The packer writes a minimal layout descriptor next to the output so you can
adjust partition size, page size and type for your board.

## What still needs a board's cooperation

A kernel `Image` alone is not a bootable image. The ramdisk, DTB/DTBO and the
boot configuration come from the board's OpenHarmony port, not from the kernel
lane. The artifacts a lane produces are:

| artifact | board-specific? |
| --- | --- |
| `Image` | no — this is the deliverable |
| `Image.gz`, `System.map`, `vmlinux` | no |
| `*.dtb`, `*.dtbo` | **yes** — the device tree is the board's |
| `*.ko` | no |
| `header/` | no — needed to build out-of-tree modules against this kernel |
| `boot.img` | **yes** — needs ramdisk, dtb and `img_format` |

## DTB licensing caution

Device trees are data, not code, and a DTS derived from a vendor's proprietary
source may not be covered by the GPL at all. If you publish a lane's `dtbs/`,
confirm the provenance of every file. If a DTS came from a closed vendor tree,
either obtain permission or leave it out of the release. `THIRD_PARTY_LICENSES.md`
flags this; do not let it slide.
