# Config delta: `ohos-4.19`

SPDX-License-Identifier: GPL-2.0

Configuration fragments in this directory are applied **on top of** the
OpenHarmony configuration for the lanes listed below, in filename order.

**Add a fragment only when you intend to change OpenHarmony's behaviour.**
OpenHarmony's own `kernel_linux_config` is authoritative; a fragment that
merely restates one of its defaults will rot as OpenHarmony moves. Put a
comment at the top of every fragment saying what you changed and why.

Board-specific options belong in a board lane, not in `configs/base/`.

| lane | kernel repo | OpenHarmony branch | kernel | status |
| --- | --- | --- | --- | --- |
| `ohos-4.0b1-4.19` | `kernel_linux_4.19` | `OpenHarmony-4.0-Beta1` | 4.19.155 | legacy |
| `ohos-2.2-4.19` | `kernel_linux` | `OpenHarmony-2.2-Beta2` | 4.19.155 | legacy |

Verify a change with:

```bash
./ohos-kb config ohos-4.0b1-4.19
```
