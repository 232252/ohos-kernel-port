# 设备与内核对照表

SPDX-License-Identifier: GPL-2.0

## 为什么一个内核不能通用

这不是我的设计选择，是 OpenHarmony 自己的配置仓库就是这么组织的：
每个板型一份完整配置，没有一份配置覆盖所有板子。`kernel_linux_config` 里 6.6
只有 rk3568，5.10 有六个板型，4.19 走 `arch/arm/configs/` 的旧布局。

一份**不带板型**（`board: <none>`）的构建没有 GPU 驱动、没有 Wi-Fi、没有板级
pin/mux、没有触摸控制器。rk3568 那份 6193 行的配置里有 24 个 `CONFIG_MALI_BIFROST*`，
通用构建一个都拿不到。所以 `board` 是 lane 的必填维度，不是可选提示。

对照 ophub 的做法：它的 `kernel-config/release/{rk3588,rk35xx,stable}/config-<ver>`
同样是「板型族 × 内核版本」分别出 defconfig，发布 `5.10-rk35xx`、`6.6-stable` 这类
按设备分开的内核。

## OpenHarmony 7.0 公开可编译的矩阵

以下每一行都是本项目已能解析到独立板级配置的 lane（`./ohos-kb show <lane>` 可查）。

| lane | 设备/目标 | 内核 | 板型配置 | 板级配置行数 | 硬件特性 |
| --- | --- | --- | --- | --- | --- |
| `ohos-7.0-6.6-rk3568` | RK3568 类设备（香橙派 5 Plus 一类） | 6.6.101 | `rk3568` | 见下 | Mali Bifrost GPU (`MALI_PLATFORM_NAME="rk"`)、Rockchip SIP/PHY、触摸/蓝牙；OpenHarmony 7.0 在 6.6 上**唯一**的设备板型 |
| `ohos-7.0-6.6-qemu-arm64` | QEMU 模拟器 arm64 | 6.6.101 | `qemu` | 见下 | 无板级硬件，用于模拟与 CI |
| `ohos-7.0-5.10-rk3568` | RK3568 类设备 | 5.10.210 | `rk3568` | 见下 | LTS 线的 rk3568 配置，6187 行 |
| `ohos-7.0-5.10-myd_imx8mm` | MYD i.MX8M Mini | 5.10.210 | `myd_imx8mm` | 见下 | NXP i.MX8M SoC，1686 行精简配置 |
| `ohos-7.0-5.10-unionpi_tiger` | UnionPi Tiger（RK3588 级） | 5.10.210 | `unionpi_tiger` | 见下 | 6050 行，RK3588 级 SBC |
| `ohos-7.0-5.10-yangfan` | 扬帆 Yangfan 板 | 5.10.210 | `yangfan` | 见下 | 6040 行 |
| `ohos-7.0-5.10-hispark_taurus` | HiSpark Taurus（32 位） | 5.10.210 | `hispark_taurus` | 见下 | **arm 32 位**，3638 行；本项目里唯一的非 arm64 目标 |
| `ohos-7.0-5.10-qemu` | QEMU 模拟器 arm64 | 5.10.210 | `qemu` | 见下 | LTS 线模拟目标 |

## 板型配置实测行数

用真实的 `kernel_linux_config@OpenHarmony-7.0-Release` 解析，每个 lane 落到的
配置文件行数（`./tests/run-tests.sh` 的端到端断言）：

| lane | 解析出的 .config 行数 | 走的配置路径 |
| --- | --- | --- |
| `ohos-7.0-6.6-rk3568` | 6193 | `linux-6.6/rk3568/arch/arm64_defconfig`（完整） |
| `ohos-7.0-6.6-qemu-arm64` | 2323 | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig` |
| `ohos-7.0-6.6`（通用） | 1349 | `base_defconfig` + `type/standard_defconfig` |
| `ohos-7.0-5.10-rk3568` | 6187 | `linux-5.10/rk3568/arch/arm64_defconfig`（完整） |
| `ohos-7.0-5.10-unionpi_tiger` | 6050 | `linux-5.10/unionpi_tiger/arch/arm64_defconfig`（完整） |
| `ohos-7.0-5.10-yangfan` | 6040 | `linux-5.10/yangfan/arch/arm64_defconfig`（完整） |
| `ohos-7.0-5.10-hispark_taurus` | 3638 | `linux-5.10/hispark_taurus/arch/arm_defconfig`（完整，arm 32 位） |
| `ohos-7.0-5.10-myd_imx8mm` | 1174 | `linux-5.10/myd_imx8mm/arch/arm64_defconfig`（完整） |
| `ohos-7.0-5.10-qemu` | 2996 | `linux-5.10/qemu/arch/arm64_defconfig` |

## 怎么用

```bash
# 查某个板型 lane 到底用什么配置
./ohos-kb show ohos-7.0-6.6-rk3568

# 只生成配置看看会得到什么（不编译）
./ohos-kb config ohos-7.0-6.6-rk3568

# 编某一个设备的内核
./ohos-kb all ohos-7.0-6.6-rk3568

# 列出全部板型 lane
./ohos-kb list-lanes --ids --status primary
```

`--board` 会被 lane 自带的板型覆盖，所以 `ohos-kb all <lane>` 出来的就是设备内核。
要临时换板型用 `--board <name>`，但那是调试手段，正式产物应当用命名好的 lane。

## 还没有覆盖的部分（不掩饰）

* **4.19 线**只有一个 `hispark_taurus` 板型配置，布局还是旧的
  `arch/arm/configs/` 那一套，尚未纳入端到端断言。
* **NPU**：rk3568 的公开配置里**没有**任何 RKNPU 符号。OpenHarmony 的 NPU
  走的是 `drivers/acc/`（ACC 加速器框架）而非 RKNPU，公开配置里同样没有对应
  `CONFIG_`。**NPU 在这份公开配置下没有编进去**，要开需要厂商配置或额外补丁。
* **Wi-Fi**：rk3568 6.6 配置里蓝牙（BT_LE/BT_BCM/BT_RTL/USB HCI）是开的，
  但 `cfg80211`/`mac80211` 及具体 Wi-Fi 芯片驱动（MT76/MT7921/rtl8xxx/uwe5622 等）
  在该配置中**未启用**。板载 Wi-Fi 需要外挂驱动固件与额外配置。
* **4.19/5.10 旧分支**的板型只接了 rk3568，其余板型未逐条验证。
