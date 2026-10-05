# ohos-kernel-port

[English](README.md)

用 [ophub](https://github.com/ophub) 那套多内核体系的顺手程度来构建 OpenHarmony 内核：
每个可构建组合都有一条具名的 **lane**、分层配置、按序打补丁、CI 矩阵 —— 只是把目标
从 Armbian / OpenWrt 换成 OpenHarmony。

**主线目标：`OpenHarmony-7.0-Release` + Linux 6.6.101。**

---

## 这是什么

ophub 解决的是"给一堆廉价 ARM 板子、一个内核适配三种用户态"的问题。它的处境不同：
OpenHarmony 已经有内核仓、配置仓、补丁仓和构建系统，只是这些部分之间没有一条
第三方能在外面驱动的通路。

`ohos-kernel-port` 补的正是这个接口。保留 ophub 的结构，替换掉它的内核源：

| ophub | ohos-kernel-port |
| --- | --- |
| `unifreq/linux-<series>.y`、`ophub/linux-<series>.y` | `gitcode.com/openharmony/kernel_linux_<ver>` 对应的 `OpenHarmony-<x.y>-Release` 分支 |
| `kernel-config/<board>/config-<ver>` | `kernel_linux_config` 的 `base_defconfig`、`type/{small,standard}_defconfig`、板级配置 |
| `kernel-patch/{common-kernel-patches,linux-<series>.y}` | 同样的目录约定，所以现成的补丁集可以直接落进来 |
| `amlogic-s9xxx-armbian/compile-kernel/` | `ohos-kb` + `scripts/lib/*` |
| 给 Debian 用户态打 `.deb` | OpenHarmony 启动产物 |
| 每个内核都打签名 | 版本戳**默认关闭** |

## lane 矩阵

`data/ohos-kernel-lanes.tsv` 是唯一事实来源。每一行是一个可构建组合，每一行的内核
版本号都是从远端自己的 `Makefile` 里读出来的，不是猜的。

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

共 28 条 lane：22 条由 OpenHarmony 内核仓支撑，6 条把 ophub 的主线版本广度接过来，
在主线源码上套用 OpenHarmony 配置。

`ohos-kb verify` 会重新读每条 lane 远端的 `Makefile` 并报告漂移，不克隆任何东西就能核对矩阵。

## 用法

```bash
./ohos-kb doctor                          # 看这台机器能构建什么
./ohos-kb show ohos-7.0-6.6               # 解析一条 lane
./ohos-kb all ohos-7.0-6.6                # 取源 → 打补丁 → 配置 → 编译 → 打包
./ohos-kb all primary --board rk3568      # 加上 OpenHarmony 板级层
./ohos-kb config ohos-7.0-6.6             # 只生成配置
./ohos-kb verify                          # 拿矩阵跟远端核对
./ohos-kb list-lanes --status primary
```

完整选项见 `ohos-kb help`。

## 我们和 ophub 不一样的地方，以及为什么

**OpenHarmony 配置仓是强制的。** 在 `kernel_linux_6.6 @ OpenHarmony-7.0-Release`
上实测：内核树自带的 `arch/arm64/configs/defconfig` 只覆盖了 OpenHarmony
`base_defconfig` + `type/standard_defconfig` 所设 798 个符号中的 **110 个**，13 %。
缺的 652 个里包括 `CONFIG_ACCESS_TOKENID` 和 `CONFIG_ANDROID_BINDER_IPC`。
拿 in-tree defconfig 编出来的是主线内核，不是 OpenHarmony 内核。所以 `ohos-kb`
一定会去取 `kernel_linux_config`，会打印底座是哪一层给的，一旦不得不回退就大声告警；
CI 会在这些符号缺失时直接判失败。详见 [configs/README.md](configs/README.md)。

**它不会伪造 `boot.img`。** OpenHarmony 的启动镜像**不是** Android 的启动镜像，
用的是 OpenHarmony 自己的 `img_format` 头格式，而这个工具只存在于闭源 prebuilts 里。
与其丢给你一个 OpenHarmony bootloader 根本点不亮的 `mkbootimg` 产物，不如把原始
`Image` 加上 `boot-img-cmd.txt`（里面是补完这步的确切命令）一起交给你。
详见 [docs/BOOT-IMAGE.md](docs/BOOT-IMAGE.md)。

**版本戳默认关闭。** ophub 每个内核都打戳，因为 Armbian / OpenWrt 靠版本串匹配。
OpenHarmony 不需要，而一个意料之外的 `LOCALVERSION` 只会让产物无端偏离它声称对应的
那个发行版。想要的话用 `--sign`。

## 现状

| | |
| --- | --- |
| lane 矩阵 | 已与远端逐条核对，28 条 |
| 自测 | 39 项通过（`tests/run-tests.sh`） |
| CI | 配置检查、构建、夜间矩阵 |
| 本地完整构建 | 作者沙箱未跑（2 核 3 GB 内存）—— 以 CI 为准 |

OpenHarmony 自己这边 6.6 的板子覆盖很窄：在 `OpenHarmony-7.0-Release` 上，
`kernel_linux_config` 只为 `rk3568` 和 `qemu` 系列提供了配置；5.10 那条线则覆盖
`rk3399`、`myd_imx8mm`、`unionpi_tiger`、`yangfan`、`hispark_*` 和 `qemu`。
所以一条 lane 可以给 OpenHarmony 没配置过的板子构建内核 —— 详见
[docs/PORTING-NOTES.md](docs/PORTING-NOTES.md)。

## 文档

* [docs/BOARDS.md](docs/BOARDS.md) — **哪个设备用哪个内核**，以及为什么通用内核不可用
* [docs/VERSION-MATRIX.md](docs/VERSION-MATRIX.md) — 全部 lane 及其核实方式
* [docs/PORTING-NOTES.md](docs/PORTING-NOTES.md) — ophub 与 OpenHarmony 的差异与坑
* [docs/BOOT-IMAGE.md](docs/BOOT-IMAGE.md) — 启动镜像格式问题
* [docs/COMPLIANCE.md](docs/COMPLIANCE.md) — 本项目满足的 GPL-2.0 义务
* [configs/README.md](configs/README.md) — 配置分层

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)，需要签署 DCO。

## 许可

GPL-2.0-only。这不是选择的结果 —— 为什么 ophub 与 Linux 内核的派生作品不能改许可，
见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

    Copyright (C) 2021 ophub contributors
    Copyright (C) 2021 https://github.com/unifreq/openwrt_packit
    Copyright (C) 2026 ohos-kernel-port contributors

`LICENSE` 是 FSF GPL-2.0 原文，逐字节未改。`NOTICE` 记录相对 ophub 的改动，并载明商标免责声明。

## 商标

本项目是独立社区项目，与华为技术有限公司、开放原子开源基金会、OpenHarmony 项目、
ophub、unifreq、Armbian、OpenWrt Project 均无隶属、授权、合作或背书关系。
`OpenHarmony` 与其 Logo 是开放原子开源基金会的商标；`HarmonyOS`、`华为` 是华为技术
有限公司的商标；`Armbian`、`OpenWrt` 是各自权利人的商标。此处均仅为描述性引用，
本项目不复制任何 Logo 或品牌标识。
