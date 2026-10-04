# Config delta: `ohos-rk35xx`

SPDX-License-Identifier: GPL-2.0

Configuration fragments in this directory are applied **on top of** the
OpenHarmony configuration for the lanes listed below, in filename order.

**Add a fragment only when you intend to change OpenHarmony's behaviour.**
OpenHarmony's own `kernel_linux_config` is authoritative; a fragment that
merely restates one of its defaults will rot as OpenHarmony moves. Put a
comment at the top of every fragment saying what you changed and why.

Board-specific options belong in a board lane, not in `configs/base/`.

Also used by the mainline lanes carried over from ophub:

- `upstream-5.10.y-rk35xx` — `linux-5.10.y-rk35xx` (5.10.y-rk35xx, experimental)

Verify a change with:

```bash
./ohos-kb config upstream-5.10.y-rk35xx
```
