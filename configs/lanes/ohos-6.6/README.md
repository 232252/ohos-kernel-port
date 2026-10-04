# Config delta: `ohos-6.6`

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
| `ohos-7.0-6.6` | `kernel_linux_6.6` | `OpenHarmony-7.0-Release` | 6.6.101 | primary |
| `ohos-7.0b-6.6` | `kernel_linux_6.6` | `OpenHarmony-7.0-Beta1` | 6.6.101 | stable |
| `ohos-6.1-6.6` | `kernel_linux_6.6` | `OpenHarmony-6.1-Release` | 6.6.101 | stable |
| `ohos-6.1lts-6.6` | `kernel_linux_6.6` | `OpenHarmony-6.1-LTS` | 6.6.101 | stable |
| `ohos-6.0-6.6` | `kernel_linux_6.6` | `OpenHarmony-6.0-Release` | 6.6.101 | stable |
| `ohos-6.0b-6.6` | `kernel_linux_6.6` | `OpenHarmony-6.0-Beta1` | 6.6.89 | stable |
| `ohos-5.1-6.6` | `kernel_linux_6.6` | `OpenHarmony-5.1.0-Release` | 6.6.89 | stable |
| `ohos-5.0-6.6` | `kernel_linux_6.6` | `OpenHarmony-5.0.0-Release` | 6.6.22 | legacy |

Verify a change with:

```bash
./ohos-kb config ohos-7.0-6.6
```
