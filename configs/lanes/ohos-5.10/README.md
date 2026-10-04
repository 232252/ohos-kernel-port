# Config delta: `ohos-5.10`

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
| `ohos-7.0-5.10` | `kernel_linux_5.10` | `OpenHarmony-7.0-Release` | 5.10.210 | primary |
| `ohos-7.0b-5.10` | `kernel_linux_5.10` | `OpenHarmony-7.0-Beta1` | 5.10.210 | stable |
| `ohos-6.1-5.10` | `kernel_linux_5.10` | `OpenHarmony-6.1-Release` | 5.10.210 | stable |
| `ohos-6.1lts-5.10` | `kernel_linux_5.10` | `OpenHarmony-6.1-LTS` | 5.10.210 | stable |
| `ohos-6.0-5.10` | `kernel_linux_5.10` | `OpenHarmony-6.0-Release` | 5.10.210 | stable |
| `ohos-5.1-5.10` | `kernel_linux_5.10` | `OpenHarmony-5.1.0-Release` | 5.10.210 | stable |
| `ohos-5.0-5.10` | `kernel_linux_5.10` | `OpenHarmony-5.0.0-Release` | 5.10.208 | legacy |
| `ohos-4.1-5.10` | `kernel_linux_5.10` | `OpenHarmony-4.1-Release` | 5.10.184 | legacy |
| `ohos-4.0-5.10` | `kernel_linux_5.10` | `OpenHarmony-4.0-Release` | 5.10.165 | legacy |
| `ohos-3.2-5.10` | `kernel_linux_5.10` | `OpenHarmony-3.2-Release` | 5.10.97 | legacy |
| `ohos-3.1-5.10` | `kernel_linux_5.10` | `OpenHarmony-3.1-Release` | 5.10.79 | legacy |
| `ohos-3.0-5.10` | `kernel_linux_5.10` | `OpenHarmony-3.0-LTS` | 5.10.57 | legacy |

Verify a change with:

```bash
./ohos-kb config ohos-7.0-5.10
```
