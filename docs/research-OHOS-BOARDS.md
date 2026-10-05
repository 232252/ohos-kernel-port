# REPORT-H — OpenHarmony 7.0 出货产品/板型 → 内核仓/分支/配置 映射调研

> 调研范围：`manifest@OpenHarmony-7.0-Release` 及其引用的全部仓，全部 revision 均为 `OpenHarmony-7.0-Release`。
> 调研日期：2026-10-06。所有结论均给出 `文件:行号` 或 API URL 证据。**未查到的一律写"未查到"，不臆造。**
> 本文件为新增调研产物，未修改 `.research/recon` 下任何既有文件。

---

## 0. 一句话结论

OpenHarmony 7.0 **真正有公开、可编译内核配置的标准系统（Linux）板型只有 2 个半**：
`hihope/rk3568`（dayu200 系，5.10 与 6.6 双版本）、`hisilicon/hispark_taurus`（hi3516DV300，仅 5.10）、
以及 QEMU 模拟板（arm/arm64 virt，5.10 与 6.6）。
`wukong100`（UNISOC p7885）虽在 manifest 中声明，但**其内核仓 `kernel_unisoc_p7885` 在 gitcode 上 404，不存在**，无法构建。

---

## 1. 7.0 的产品定义在哪、怎么组织

### 1.1 manifest 骨架

`manifests/manifest-OpenHarmony-7.0-Release/default.xml:19-21`
```xml
<include name="ohos/ohos.xml"/>     <!-- 平台仓，509 个 <project> -->
<include name="chipsets/all.xml"/>  <!-- 芯片仓汇总 -->
```

`chipsets/all.xml:6-9` — 7.0 只有 **4 个 chipset**：
```xml
<include name="chipsets/hispark/hispark.xml"/>
<include name="chipsets/dayu200/dayu200.xml"/>
<include name="chipsets/qemu/qemu.xml"/>
<include name="chipsets/wukong100/wukong100.xml"/>   <!-- 7.0 新增 -->
```

### 1.2 与产品/板型/内核相关的 project 条目（全部 revision = `OpenHarmony-7.0-Release`）

| manifest 文件:行 | name | path | groups |
|---|---|---|---|
| `ohos/ohos.xml:253` | `productdefine_common` | `productdefine/common` | default,mini,small,standard,system,chipset |
| `ohos/ohos.xml:452` | `kernel_linux_config` | `kernel/linux/config` | default,small,standard,chipset |
| `ohos/ohos.xml:453` | `kernel_linux_patches` | `kernel/linux/patches` | — |
| `ohos/ohos.xml:454` | `kernel_linux_build` | `kernel/linux/build` | — |
| `ohos/ohos.xml:455` | `kernel_linux_5.10` | `kernel/linux/linux-5.10` | default,small,standard,system,chipset (clone-depth=1) |
| `ohos/ohos.xml:456` | `kernel_linux_6.6` | `kernel/linux/linux-6.6` | default,small,standard,system,chipset (clone-depth=1) |
| `ohos/ohos.xml:457` | `kernel_linux_common_modules` | `kernel/linux/common_modules` | default,small,standard,system,chipset |
| `ohos/ohos.xml` | `kernel_liteos_a` | `kernel/liteos_a` | — |
| `ohos/ohos.xml` | `kernel_liteos_m` | `kernel/liteos_m` | — |
| `ohos/ohos.xml` | `kernel_uniproton` | `kernel/uniproton` | — |
| `chipsets/hispark/hispark.xml:5-7` | `device_soc_hisilicon` | `device/soc/hisilicon` | mini,small,standard,chipset |
| `chipsets/hispark/hispark.xml:6` | `device_board_hisilicon` | `device/board/hisilicon` | mini,small,standard,chipset |
| `chipsets/hispark/hispark.xml:7` | `vendor_hisilicon` | `vendor/hisilicon` | mini,small,standard,chipset |
| `chipsets/dayu200/dayu200.xml:5` | `device_board_hihope` | `device/board/hihope` | mini,small,standard,chipset |
| `chipsets/dayu200/dayu200.xml:6` | `device_soc_rockchip` | `device/soc/rockchip` | standard,chipset |
| `chipsets/dayu200/dayu200.xml:7` | `vendor_hihope` | `vendor/hihope` | mini,standard,chipset |
| `chipsets/qemu/qemu.xml:5` | `device_qemu` | `device/qemu` | mini,small,standard,chipset |
| `chipsets/qemu/qemu.xml:6` | `vendor_ohemu` | `vendor/ohemu` | mini,small,standard,chipset (+linkfile `common/qemu-run`) |
| `chipsets/wukong100/wukong100.xml:23-25` | `device_board_revoview` | `device/board/revoview` | mini,small,standard,chipset |
| `chipsets/wukong100/wukong100.xml:24` | `device_soc_unisoc` | `device/soc/unisoc` | standard,chipset |
| `chipsets/wukong100/wukong100.xml:25` | `vendor_revoview` | `vendor/revoview` | mini,standard,chipset |

**关键事实：7.0 manifest 中没有 `kernel_linux_4.19`**（4.19 只存在于 `kernel_linux_config` 的配置文件里，内核源码仓已从 7.0 manifest 移除）。

### 1.3 `productdefine/common` 里有什么（重要：没有板级产品定义）

`productdefine_common@OpenHarmony-7.0-Release` 完整文件树（`git ls-tree -r`，共 17 文件）：
```
base/mini_system.json          base/small_system.json       base/standard_system.json
inherit/2in1.json   inherit/chipset_common.json  inherit/headless.json
inherit/ipcamera.json  inherit/liteWearable.json  inherit/phone.json
inherit/rich.json   inherit/tablet.json  inherit/tv.json  inherit/wearable.json
products/ohos-sdk.json
products/system_arm64_default.json     products/system_arm_default.json
```

→ **`productdefine/common/*.json` 在 7.0 已退化为"基类/继承片段"，不再包含任何 rk3568 / hispark / qemu 板级产品定义。**
板级产品定义搬到了 **`vendor/<company>/<product>/config.json`**，通过 `"inherit"` 字段引用 `productdefine/common/...`。
证据：`vendor_hihope/rk3568/config.json:13` → `"inherit": [ "productdefine/common/inherit/rich.json", "productdefine/common/inherit/chipset_common.json" ]`。

`productdefine/common/products/system_arm64_default.json:2-5`：`product_name=system_arm64_default, device_company=ohos, target_cpu=arm64, board=arm64, type=standard`。

### 1.4 `device/board/*` 下的实际板目录（7.0-Release 真实存在）

| repo | 板目录（顶层条目） |
|---|---|
| `device_board_hihope` | `dayu210`, `hcs`, `nearlink_dk_3863`, `neptune100`, `picture`, `rk3568`, `shields` |
| `device_board_hisilicon` | `hispark_aries`, `hispark_pegasus`, `hispark_phoenix`, `hispark_taurus` |
| `device_board_revoview` | `patches`, `picture`, `wukong100` |
| `device_qemu` | `SmartL_E802`, `arm_mps2_an386`, `arm_mps3_an547`, `arm_virt`, `common`, `drivers`, `esp32`, `hardware`, `riscv32_virt`, `riscv64_virt`, `x86_64_virt` |

`device/soc` 仓内容：`device_soc_rockchip` = `rk2206, rk3399, rk3566, rk3568, rk3588, common`；
`device_soc_hisilicon` = `hi3516dv300, hi3518ev300, hi3751v350, hi3861v100, ws63v100, common`；
`device_soc_unisoc` = `p7885`。

### 1.5 6.1 → 7.0 差异（板型层面）

| | 6.1-Release | 7.0-Beta1 | 7.0-Release |
|---|---|---|---|
| chipsets | hispark, dayu200, qemu | hispark, dayu200, qemu | hispark, dayu200, qemu, **wukong100** |
| device/board 仓 | hihope, hisilicon, (qemu) | hihope, hisilicon, (qemu) | hihope, hisilicon, **revoview** |
| device/soc 仓 | hisilicon, rockchip | hisilicon, rockchip | hisilicon, rockchip, **unisoc** |
| vendor 仓 | hihope, hisilicon, ohemu | hihope, hisilicon, ohemu | hihope, hisilicon, ohemu, **revoview** |
| Linux 内核仓 | 5.10 + 6.6 | 5.10 + 6.6 | 5.10 + 6.6（无 4.19） |

→ 7.0 相对 6.1 的板型变化**只有"新增 UNISOC p7885 / wukong100"这一件事**，其余板型完全一致。

---

## 2. 产品 → 板型 → 内核 映射主表

### 2.0 前置：三种（实际是五种）配置取用机制

| 机制 | 谁在用 | 配置路径规则 | 证据 |
|---|---|---|---|
| **A** 板级 `build_kernel.sh`（hihope 新式） | `rk3568` | `kernel/linux/config/$KERNEL_VERSION/$DEVICE_NAME/arch/arm64_defconfig` + `base_defconfig` + `type/standard_defconfig` | `device_board_hihope:rk3568/kernel/build_kernel.sh:24,31,45-51` |
| **B** `kernel_linux_build/kernel.mk` | `hispark_taurus`, `hispark_phoenix`, qemu `*_min`/`*_headless` | `make $DEVICE_NAME_$BUILD_TYPE_defconfig`，即 `linux-$V/arch/$ARCH/configs/<dev>_<type>_defconfig` | `kernel_linux_build:kernel.mk:29,89,162,164` |
| **C** 板级自带 config 目录（hihope 旧式） | `dayu210` | 板内 `kernel/kernel_config/linux-5.10/arch/arm64/rk3588_standard_defconfig` + `kernel/linux/config/linux-5.10/base_defconfig` | `device_board_hihope:dayu210/kernel/build_kernel.sh:22,34,106` |
| **D** 独立内核仓 | `wukong100` | 板内 `kernel/wukong100_defconfig` | `device_board_revoview:wukong100/kernel/BUILD.gn:18-19` |
| **E** qemu `linux_full` | `arm64_virt`, `x86_64_virt` | 板内 `common/virt_full/kernel/{arm64_virt,arm_virt}_defconfig` | `device_qemu:common/virt_full/kernel/BUILD.gn:9` |

**全局默认内核版本**：`build@7.0/ohos/kernel/kernel.gni:13-15`
```gn
declare_args() {
  linux_kernel_version = "linux-6.6"     # ← 全局默认
}
```
我逐一扫描了 `device_board_hihope / hisilicon / revoview / device_qemu / vendor_hihope / hisilicon / revoview / ohemu`
全部 `*.gni`，**没有任何一处 override `linux_kernel_version`**（`/tmp/gw/final.log` = `FINAL_DONE` 且无 `OVERRIDE` 行）。
因此：只要板子不硬编码、config.json 不声明，实际拿到的就是 `linux-6.6`。

### 2.1 主表

| # | 产品（vendor/<company>/<product>） | 板型 (device/board) | vendor | SoC (device/soc) | 内核仓 | 内核版本 | 配置路径（相对 `kernel/linux/config/`） | 机制 | 证据 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `hihope/rk3568` | `hihope/rk3568` | hihope | `rockchip/rk3568` | `kernel_linux_6.6` | **6.6.101** | `linux-6.6/rk3568/arch/arm64_defconfig` | A | `vendor_hihope:rk3568/config.json:8` `"board":"rk3568"`；`rk3568/kernel/BUILD.gn:16-17,37`；`rk3568/kernel/build_kernel.sh:24,45-51` |
| 1b | 同上（5.10 变体） | `hihope/rk3568` | hihope | `rockchip/rk3568` | `kernel_linux_5.10` | **5.10.210** | `linux-5.10/rk3568/arch/arm64_defconfig` | A | 同上；`matrix_product.csv` 中 `kernel_linux_5.10` 对 `dayu200` = Y |
| 2 | `hihope/rk3568_mini_system` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1/#1b | 6.6.101 或 5.10.210 | 同 #1/#1b | A | `vendor_hihope:rk3568_mini_system/config.json` `"board":"rk3568"` |
| 3 | `hihope/2in1_core_system` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:2in1_core_system/config.json:8` |
| 4 | `hihope/default_core_system` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:default_core_system/config.json:8` |
| 5 | `hihope/ipcamera_core_system` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:ipcamera_core_system/config.json:8` |
| 6 | `hihope/tablet_core_system` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:tablet_core_system/config.json:8` |
| 7 | `hihope/tv` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:tv/config.json:8` |
| 8 | `hihope/wearable` | `hihope/rk3568` | hihope | `rockchip/rk3568` | 同 #1 | 同 #1 | 同 #1 | A | `vendor_hihope:wearable/config.json:8` |
| 9 | `hihope/dayu210` | `hihope/dayu210` | hihope | **`rockchip/rk3588`** | `kernel_linux_5.10` | **5.10.210（硬编码）** | **板内** `device/board/hihope/dayu210/kernel/kernel_config/linux-5.10/arch/arm64/rk3588_standard_defconfig` | C | `vendor_hihope:dayu210/config.json:8` `"board":"rk3588"`；`dayu210/kernel/build_kernel.sh:22` `KERNEL_VERSION=linux-5.10`、`:30`、`:34`、`:106`；`dayu210/device.gni:15` `soc_name="rk3588"` |
| 10 | `hisilicon/hispark_taurus_linux` | `hisilicon/hispark_taurus` | hisilicon | `hisilicon/hi3516dv300` | `kernel_linux_5.10` | **5.10.210** | `linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig` | B | `vendor_hisilicon:hispark_taurus_linux/config.json:10-11` `"kernel_type":"linux"`,`"kernel_version":"5.10"`；`hispark_taurus/device.gni:15` `soc_name="hi3516dv300"`；`hispark_taurus_standard/config.json:5` `"target_cpu":"arm"` → `ARCH=arm` |
| 11 | `hisilicon/hispark_taurus_linux_ex` | 同 #10 | hisilicon | `hi3516dv300` | `kernel_linux_5.10` | 5.10.210 | 同 #10 | B | `vendor_hisilicon:hispark_taurus_linux_ex/config.json` 同字段 |
| 12 | `hisilicon/hispark_taurus_standard` | 同 #10 | hisilicon | `hi3516dv300` | ⚠ 无可用配置 | — | `linux-6.6/arch/arm/configs/hispark_taurus_standard_defconfig` **不存在** | B | `vendor_hisilicon:hispark_taurus_standard/config.json` **无 `kernel_version` 字段** → 落回默认 `linux-6.6`，但 `kernel_linux_config@7.0` 的 `linux-6.6/` 下只有 4 个文件，无 hispark |
| 13 | `hisilicon/hispark_phoenix` | `hisilicon/hispark_phoenix` | hisilicon | `hisilicon/hi3751v350` | `kernel_linux_5.10` | 5.10.210 | `linux-5.10/arch/arm/configs/hispark_phoenix_standard_defconfig` | B | `hispark_phoenix/device.gni:15` `soc_name="hi3751v350"`；`kernel_linux_build:kernel.mk:58-59,108` 对 `hispark_phoenix` 特判；板内为预编译 `linux/boot/*.bin`（`atf.bin`/`uboot.img`/`slaveboot.img`/`logo.img`） |
| 14 | `hisilicon/watchos` | `hisilicon/hispark_taurus` | hisilicon | `hi3516dv300` | ⚠ `kernel_linux_4.19` **不在 7.0 manifest** | 4.19.x | `linux-4.19/arch/arm/configs/hispark_taurus_standard_defconfig`（配置存在，源码仓缺失） | B | `vendor_hisilicon:watchos/config.json` `"board":"hi3516dv300"`,`"kernel_type":"linux"`,`"kernel_version":"4.19"`；`kernel_linux_build:kernel.mk:86` `PRODUCT_PATCH_FILE=vendor/hisilicon/watchos/patches/...` |
| 15 | `ohemu/qemu_arm64_linux_full` | `device/qemu/arm_virt/linux_full` | ohemu | (QEMU virt) | `kernel_linux_6.6` | **6.6.101（硬编码）** | 板内 `device/qemu/common/virt_full/kernel/arm64_virt_defconfig` | E | `device_qemu:common/virt_full/kernel/BUILD.gn:9` `kernel_source_dir = "//kernel/linux/linux-6.6"` |
| 16 | `ohemu/qemu_x86_64_linux_full` | `device/qemu/x86_64_virt/linux_full` | ohemu | (QEMU virt) | `kernel_linux_6.6` | 6.6.101（硬编码） | 板内 `device/qemu/common/virt_full/kernel/configs/arm_virt_defconfig` | E | 同上 |
| 17 | `ohemu/qemu_arm64_linux_min` | `device/qemu/arm_virt/linux` | ohemu | (QEMU virt) | 5.10 或 6.6（默认 6.6） | 6.6.101 | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig` | B | `vendor_ohemu:qemu_arm64_linux_min/config.json` `"board":"qemu-arm-linux"`；`device/qemu/arm_virt/linux/ohos.build` |
| 18 | `ohemu/qemu_arm_linux_min` / `qemu_arm_linux_headless` | `device/qemu/arm_virt/linux` | ohemu | (QEMU virt) | 5.10 或 6.6 | 6.6.101 或 5.10.210 | `linux-6.6/arch/arm/configs/qemu-arm-linux_standard_defconfig` | B | 同上，`target_cpu=arm` |
| 19 | `ohemu/qemu_riscv64_linux_min` | `device/qemu/riscv64_virt/linux` | ohemu | (QEMU) | 5.10 only | 5.10.210 | `linux-5.10/arch/riscv/configs/qemu-riscv64-linux_standard_defconfig` | B | `kernel_linux_config` 6.6 无 riscv 目录 |
| 20 | `ohemu/qemu_loongarch64_linux_min` | `device/qemu/loongarch64_virt/linux` | ohemu | (QEMU) | 5.10 only | 5.10.210 | `linux-5.10/arch/loongarch/configs/qemu-loongarch64-linux_standard_defconfig` | B | 同上 |
| 21 | `revoview/wukong100` | `revoview/wukong100` | revoview | `unisoc/p7885` | ❌ **`kernel_unisoc_p7885` 不存在** | (构建脚本写死 `linux-5.15`) | 板内 `device/board/revoview/wukong100/kernel/wukong100_defconfig` | D | `wukong100/kernel/BUILD.gn:18-19` `kernel_source_dir = "//kernel_unisoc_p7885"`；`:22` outputs `.../OBJ/linux-5.15/...`；`wukong100/device.gni:15` `soc_name="p7885"`；仓库 404 证据见 §2.3 |
| 22 | `hisilicon/hispark_taurus` | `hispark_taurus` | hisilicon | `hi3516dv300` | **无 Linux 内核** | — | — | LiteOS-A | `vendor_hisilicon:hispark_taurus/config.json` `"kernel_type":"liteos_a"` |
| 23 | `hisilicon/hispark_taurus_mini_system` | `hispark_taurus` | hisilicon | `hi3516dv300` | 无 Linux 内核 | — | — | LiteOS-A | 同上 |
| 24 | `hisilicon/hispark_pegasus` (+`_mini_system`, `_minimal`) | `hispark_pegasus` | hisilicon | `hi3861v100` | 无 Linux 内核 | — | — | LiteOS-M | `vendor_hisilicon:hispark_pegasus/config.json` `"kernel_type":"liteos_m"`；`hispark_pegasus/ohos.build` 只引 `device/soc/hisilicon/hi3861v100` |
| 25 | `hisilicon/hispark_aries` | `hispark_aries` | hisilicon | (未查到 soc) | 无 Linux 内核 | — | — | LiteOS-A | `vendor_hisilicon:hispark_aries/config.json` `"kernel_type":"liteos_a"` |
| 26 | `hihope/neptune_iotlink_demo` | `neptune100` | hihope | (liteos_m 板) | 无 Linux 内核 | `3.0.0` | — | LiteOS-M | `vendor_hihope:neptune_iotlink_demo/config.json` |
| 27 | `hihope/nearlink_dk_3863` (+`_xts`, `_xts_minimal`) | `nearlink_dk_3863` | hihope | — | 无 Linux 内核 | — | — | LiteOS-M | `vendor_hihope:nearlink_dk_3863/config.json` `"kernel_type":"liteos_m"` |
| 28 | `ohemu/qemu_*_mini_system_demo` (7 个) | `arm_mps2_an386`/`arm_mps3_an547`/`SmartL_E802`/`riscv32_virt`/`esp32`/`arm_virt` | ohemu | — | 无 Linux 内核 | `3.0.0`/`3.0.0.mini` | — | LiteOS-M/A | `vendor_ohemu:qemu_cm55_mini_system_demo/config.json` 等 |

### 2.2 `hispark_taurus` 的两条路径（务必注意）

`hispark_taurus` 板同时存在两套构建入口，**内核版本完全不同**：

| 入口 | 设备路径 | 目标 | 用哪份配置 |
|---|---|---|---|
| small/轻量 | `device/board/hisilicon/hispark_taurus/liteos_a/` | LiteOS-A | `kernel/liteos_a` |
| standard/Linux | `device/board/hisilicon/hispark_taurus/linux/` | Linux | `kernel_linux_build` → `kernel.mk` |
| 板内 Linux 配置片段 | `device/board/hisilicon/hispark_taurus/linux/config.gni` | — | 板级 CPU/arch 定义 |

`kernel_linux_build:kernel.mk:89` `DEFCONFIG_FILE := $(DEVICE_NAME)_$(BUILD_TYPE)_defconfig`
→ `hispark_taurus` + `standard` ⇒ `linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig`（该文件在 7.0 配置仓中**存在**）。

### 2.3 `kernel_unisoc_p7885` 不存在的证据

```
$ git ls-remote --heads https://gitcode.com/openharmony/kernel_unisoc_p7885.git
remote: <CH.00905403> The project you were looking for could not be found.
fatal: ... 403

$ curl https://api.gitcode.com/api/v5/repos/openharmony/kernel_unisoc_p7885
{"error_code":404,"error_code_name":"UN_KNOW","error_message":"Project not found:openharmony/kernel_unisoc_p7885"}
```
且该仓**不在** `manifest@OpenHarmony-7.0-Release` 的任何 XML 中（`grep -iE 'unisoc|p7885' ohos.xml chipsets/*/*.xml` 只命中 `device_soc_unisoc`）。
⇒ **wukong100 在 7.0 上无法从官方 manifest 完整构建。**

### 2.4 `kernel_linux_config@OpenHarmony-7.0-Release` 全部 35 个 defconfig（权威清单）

`git ls-tree -r --name-only origin/OpenHarmony-7.0-Release`（HEAD = `34b9a9a`），完整 41 条（含 5 个非 defconfig 文件）：

```
linux-4.19/arch/arm/configs/hispark_taurus_small_defconfig
linux-4.19/arch/arm/configs/hispark_taurus_standard_defconfig
linux-4.19/arch/arm/configs/small_common_defconfig
linux-4.19/arch/arm/configs/standard_common_defconfig
linux-5.10/arch/arm/configs/hispark_phoenix_standard_defconfig
linux-5.10/arch/arm/configs/hispark_taurus_small_defconfig
linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig
linux-5.10/arch/arm/configs/qemu-arm-linux_standard_defconfig
linux-5.10/arch/arm/configs/small_common_defconfig
linux-5.10/arch/arm/configs/standard_common_defconfig
linux-5.10/arch/arm64/configs/myd_imx8mm_defconfig
linux-5.10/arch/arm64/configs/qemu-arm-linux_standard_defconfig
linux-5.10/arch/arm64/configs/rk3399_standard_defconfig
linux-5.10/arch/arm64/configs/rk3568_standard_defconfig
linux-5.10/arch/arm64/configs/unionpi_tiger_standard_defconfig
linux-5.10/arch/loongarch/configs/qemu-loongarch64-linux_standard_defconfig
linux-5.10/arch/riscv/configs/qemu-riscv64-linux_standard_defconfig
linux-5.10/arch/x86/configs/qemu-x86_64-linux_standard_defconfig
linux-5.10/base_defconfig
linux-5.10/hispark_taurus/arch/arm_defconfig
linux-5.10/imx8mm/arch/arm64_defconfig
linux-5.10/qemu/arch/arm64_defconfig
linux-5.10/qemu/arch/arm_defconfig
linux-5.10/qemu/arch/x86_64_defconfig
linux-5.10/rk3568/arch/arm64_defconfig
linux-5.10/type/small_defconfig
linux-5.10/type/standard_defconfig
linux-5.10/unionpi_tiger/arch/arm64_defconfig
linux-5.10/yangfan/arch/arm64_defconfig
linux-6.6/arch/arm/configs/qemu-arm-linux_standard_defconfig
linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig
linux-6.6/arch/arm64/configs/rk3568_standard_defconfig
linux-6.6/base_defconfig
linux-6.6/rk3568/arch/arm64_defconfig
linux-6.6/type/small_defconfig
linux-6.6/type/standard_defconfig
```

**`linux-6.6/` 一共只有 4 个配置 + base/type，共 7 个文件。这就是 6.6.101 的全部板型覆盖面。**
（本地交叉校验：该树与已有只读副本 `.research/recon/ohtrees/kernel_linux_config.txt` 逐条一致。）

### 2.5 内核版本号权威确认

```
kernel_linux_5.10@OpenHarmony-7.0-Release  Makefile: VERSION=5 PATCHLEVEL=10 SUBLEVEL=210  → 5.10.210
kernel_linux_6.6@OpenHarmony-7.0-Release  Makefile: VERSION=6 PATCHLEVEL=6  SUBLEVEL=101  → 6.6.101
```

### 2.6 CI 门禁交叉验证（`matrix_product.csv`，manifest 仓根目录）

各仓在 7.0 各编译形态下是否 `Y`（节选，只列设备/内核相关）：

| repo | dayu200 | hispark_taurus_Linux | hispark_taurus_LiteOS | hispark_pegasus | Emulator | part_compile |
|---|---|---|---|---|---|---|
| `kernel_linux_6.6` | **Y** | **Y** | Y | N | N | N |
| `kernel_linux_5.10` | **Y** | **Y** | Y | N | **Y** | N |
| `kernel_linux_config` | **Y** | **Y** | Y | N | N | N |
| `kernel_linux_build` | **Y** | **Y** | Y | N | N | N |
| `kernel_linux_common_modules` | Y | Y | **N** | N | N | N |
| `device_board_hihope` | **Y** | N | N | N | N | N |
| `device_board_hisilicon` | N | **Y** | **Y** | Y | N | N |
| `device_soc_rockchip` | **Y** | N | N | N | N | N |
| `device_soc_hisilicon` | N | Y | Y | Y | N | N |
| `device_board_revoview` | N | Y | Y | Y | N | N |
| `device_soc_unisoc` | N | Y | Y | Y | N | N |
| `vendor_revoview` | N | Y | Y | Y | N | N |
| `device_qemu` / `vendor_ohemu` | N | N | N | N | **Y** | N |
| `productdefine_common` | Y | Y | Y | Y | Y | N |
| `kernel_liteos_a` | N | N | **Y** | N | Y | N |

另有编译形态 `dayu600_7885_7.0_release`（聚合形态：hihope + hisilicon + unisoc + revoview + qemu 全部芯片仓同时 `Y`）。
> 注意：`vendor_hihope@7.0` 下**没有 `dayu600` 目录**（只有 `dayu210`），`dayu600_7885_7.0_release` 是 CI bundle 名而非产品目录名。

### 2.7 任务假设中提到但 7.0 **不存在**的板型

对 `manifest-OpenHarmony-7.0-Release/` 全目录 grep `rpi|raspberry|树莓|orangepi|香橙|unionpi|yangfan|imx8`，
**唯一命中是 `README.md:64` 的说明性文字**（举例讲 bearpi_hm_nano/micro 的 manifest 组织方式）。

⇒ **OpenHarmony 7.0 官方 manifest 中没有树莓派 4B、没有香橙派 5Plus / Orange Pi 5 Plus、没有香橙派 4B。**
`unionpi_tiger`（RK3398）、`yangfan`、`imx8mm`/`myd_imx8mm`（i.MX8M Mini）**只以 `kernel_linux_config` 里的 defconfig 形式存在**，
在 7.0 没有对应的 `device/board/*` 板目录、没有 `vendor/*/<product>` 产品、也不在 CI 门禁里 —— 属社区/移植预留（典型用于 ohos-sdk 与第三方 BSP）。

---

## 3. 各板型配置的硬件特性清单

数据源：`kernel_linux_config@OpenHarmony-7.0-Release`，35 个 defconfig 全部逐行统计 `=y`（`=m` 另注）。
工具输出见 `/tmp/gw/SUMMARY.txt`、`/tmp/gw/hw_510.txt`；下文行号 = 该 defconfig 文件内行号。

### 3.0 汇总矩阵（数字 = 内建 `=y` 符号数；`N+Mm` = N 内建 + M 模块）

| 内核 | defconfig | GPU | RKNPU | BCMDHD | MT76/7921 | RTL8/RTW8 | AIC/AW/UNIS | CFG80211+MAC80211 | BT | ISP/V4L2 | RGA | RKVDEC/ENC | MMC_DW_RK | SDHCI | DWC3 | STMMAC | DWMAC_RK | TOUCHSCREEN | RTC_DRV | PCIE_RK | HIDE_MEM | RK_IOMMU | RK_THERMAL |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 6.6 | `linux-6.6/rk3568/arch/arm64_defconfig` | 34 | **0** | 1 | 0 | 0 | 0 | 0 | 7 | 7 | 1 | 2 | 1 | 1 | 0 | 1 | 1 | 22 | 2 | 1 | 1 | 1 | 1 |
| 6.6 | `linux-6.6/arch/arm64/configs/rk3568_standard_defconfig` | 40 | **0** | 1 | 0 | 0 | 0 | 2 | 7 | 7 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 22 | 2 | 1 | 0 | 1 | 1 |
| 5.10 | `linux-5.10/rk3568/arch/arm64_defconfig` | 34 | **0** | 1 | 0 | 0 | 0 | 0 | 7 | 7 | 1 | 2 | 1 | 1 | 0 | 1 | 1 | 22 | 2 | 1 | 1 | 1 | 1 |
| 5.10 | `linux-5.10/arch/arm64/configs/rk3568_standard_defconfig` | 40 | **0** | 1 | 0 | 0 | 0 | 2 | 7 | 7 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 22 | 2 | 1 | 0 | 1 | 1 |
| 5.10 | `linux-5.10/yangfan/arch/arm64_defconfig` | 36 | **0** | **2** | 0 | 0 | 0 | 0 | 7 | 7 | 1 | 2 | 1 | 1 | 0 | 1 | 1 | 22 | 2 | 1 | 0 | 1 | 1 |
| 5.10 | `linux-5.10/arch/arm64/configs/rk3399_standard_defconfig` | 42 | **0** | 2 | 0 | 0 | 0 | 2 | 7 | 7 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 22 | 2 | 1 | 0 | 1 | 1 |
| 5.10 | `linux-5.10/unionpi_tiger/arch/arm64_defconfig` | 16+2m | 0 | 0 | 0 | **1** | 0 | 0 | 4 | 0 | 0 | 0+1m | 0 | 0 | 0 | **1** | 0 | 23 | 5+1m | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/arm64/configs/unionpi_tiger_standard_defconfig` | 24+2m | 0 | 0 | 0 | 1 | 0 | 2 | 1 | 0 | 1+1m | 0 | 0 | 1 | 1 | 0 | 0 | 23 | 6+1m | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/imx8mm/arch/arm64_defconfig` | 17+20m | 0 | **3** | 0 | 0 | 0 | 0 | 8+1m | 0 | 0 | 0 | 1 | 1 | 0 | 0+1m | 0 | 0+2m | 16+2m | 0 | 0 | 1 | 0+1m |
| 5.10 | `linux-5.10/arch/arm64/configs/myd_imx8mm_defconfig` | 19+20m | 0 | 3 | 0 | 0 | 0 | 2 | 8+1m | 0 | 0 | 0 | 1 | 1 | **1** | 0+1m | 0 | 0+2m | 16+2m | 0 | 0 | 1 | 0+1m |
| 5.10 | `linux-5.10/hispark_taurus/arch/arm_defconfig` | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig` | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |
| 4.19 | `linux-4.19/arch/arm/configs/hispark_taurus_standard_defconfig` | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/arm/configs/hispark_phoenix_standard_defconfig` | **0** | 0 | 0 | 0 | 0 | 0 | 1+1m | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/qemu/arch/arm64_defconfig` | 6+37m | 0 | 0 | 0 | 0 | 0 | 0+2m | 3+2m | 0 | 0 | 0 | 1 | 1 | 0 | 0+1m | 0 | 0+1m | 11+9m | 0 | 0 | 1 | 0+1m |
| 5.10 | `linux-5.10/qemu/arch/arm_defconfig` | 32+43m | 0 | 0 | 0 | 0 | 0 | 0+2m | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2+4m | 4+1m | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/qemu/arch/x86_64_defconfig` | 14 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| 6.6 | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig` | 6+37m | 0 | 0 | 0 | 0 | 0 | 0+2m | 3+2m | 0 | 0 | 0 | 1 | 1 | **1** | 0+1m | 0 | 0+1m | 11+9m | 0 | 0 | 1 | 0+1m |
| 6.6 | `linux-6.6/arch/arm/configs/qemu-arm-linux_standard_defconfig` | 38+43m | 0 | 0 | 0 | 0 | 0 | 0+2m | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2+4m | 4+1m | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/x86/configs/qemu-x86_64-linux_standard_defconfig` | 19 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/riscv/configs/qemu-riscv64-linux_standard_defconfig` | 9 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| 5.10 | `linux-5.10/arch/loongarch/configs/qemu-loongarch64-linux_standard_defconfig` | 22+4m | 0 | 0 | 0+1m | **0+23m** | 0 | 0+2m | 9+3m | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 0 |

### 3.1 GPU / DRM

| 板型 | 内核 | 具体型号/驱动 | 行号证据 |
|---|---|---|---|
| **rk3568 (dayu200)** | 6.6 | `CONFIG_MALI_BIFROST=y`（Arm **Mali-Bifrost** G52/G57 系）；同时残留 `MALI400/MALI450`（Midgard utgard 旧驱动）**两者同时 =y** | `linux-6.6/rk3568/arch/arm64_defconfig:3479`, `3444`, `3445`, `3458` |
| rk3568 | 6.6 | `DRM_ROCKCHIP` + `ROCKCHIP_DW_HDMI` / `CDN_DP` / `DW_MIPI_DSI` / `ANALOGIX_DP` / `DRM_SII902X` | `:3310,3312,3313,3314,3315,3400` |
| rk3568 | 6.6 | **无** `CONFIG_PANFROST`、**无** `CONFIG_POWERVR*`、**无** `CONFIG_MESA` | grep 0 命中 |
| rk3568 | 5.10 | 与 6.6 几乎逐行一致（Mali-Bifrost 同款，行号偏移 −2） | `linux-5.10/rk3568/arch/arm64_defconfig:3477,3442,3443,3308` |
| yangfan (RK3568 模组) | 5.10 | Mali-Bifrost + BCMDHD **×2** 变体 | `linux-5.10/yangfan/arch/arm64_defconfig:3384,3349,3350,1641` |
| **hispark_taurus (hi3516DV300)** | 5.10/4.19 | **无 3D GPU 驱动**。仅 `CONFIG_DRM_HISI_HISMART=y`（海思显示桥）+ `DRM_PANEL/BRIDGE/CMA_HELPER` | `linux-5.10/hispark_taurus/arch/arm_defconfig:2122,2090,2100,2101,2056,2082`；`linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig:1944` |
| hispark_phoenix (hi3751V350) | 5.10 | **完全无 DRM/GPU 符号**（GPU 计数 = 0），板子自带预编译 `slaveboot.img` | `linux-5.10/arch/arm/configs/hispark_phoenix_standard_defconfig`（grep `^CONFIG_DRM_` = 0 命中） |
| imx8mm | 5.10 | 无 3D GPU；DRM 大量为 `=m`（17+20m） | `linux-5.10/imx8mm/arch/arm64_defconfig` |
| unionpi_tiger (RK3398) | 5.10 | 16+2m，无 Mali（RK3398 用 Mali-T860，但本配置未启用任何 MALI 符号） | `linux-5.10/unionpi_tiger/arch/arm64_defconfig`（`^CONFIG_MALI` = 0 命中） |

### 3.2 NPU / AI

**全仓库 35 个 defconfig 中，`RKNPU` / `ROCKCHIP_NPU` / `RKNN` 内核符号出现次数 = 0。**

```
$ grep -rn 'RKNPU' /tmp/cfgs7/    # 35 个 7.0-Release defconfig
(无输出)
```
> 警告：正则 `CONFIG_.*NPU.*` 会误命中 `CONFIG_I-N-P-U-T`（`INPUT`）系列，已核对剔除。
> 唯一与 AI 加速沾边的是 `CONFIG_ROCKCHIP_IOMMU=y`（IOMMU 基础设施，RK3568 6.6 配置 `:4714`，5.10 配置 `:4711`）。
⇒ **rk3568/dayu200 的 NPU 在 OHOS 7.0 内核配置中完全未启用**（RK3568 本身 NPU 单元由 `rknpu` 用户态/闭源 blob 处理，此处不臆测其实现，仅陈述"内核侧无对应符号"）。

### 3.3 Wi-Fi

| 板型 | 启用的芯片驱动 | 协议栈 | 行号证据（6.6/rk3568，其余类推） |
|---|---|---|---|
| **rk3568 (dayu200)** | `CONFIG_BCMDHD=y`（**Broadcom AP6256 / BCM43456 类**，hihope rk3568 标配） | **`CONFIG_CFG80211` 与 `CONFIG_MAC80211` 均未启用**；只有 `WLAN_VENDOR_*` 厂商选择宏（`BROADCOM:1663`、`REALTEK:1701`、`QUANTENNA:1728`）和 `RFKILL_RK:967` | `linux-6.6/rk3568/arch/arm64_defconfig:1734, 1663, 1701, 1728, 967`；`grep '^CONFIG_CFG80211='` = 0 命中 |
| yangfan | `BCMDHD` ×2 | 同上 | `linux-5.10/yangfan/arch/arm64_defconfig:1641` |
| imx8mm / myd_imx8mm | `BCMDHD` ×3 变体 | `BT_HCIBTUSB=m` + `BT_HCIUART=y`（UART HCI 为主） | `linux-5.10/imx8mm/arch/arm64_defconfig:322,154,155` |
| hispark_taurus | **无任何 Wi-Fi 芯片驱动** | 仅 `CONFIG_WIRELESS=y:791` + `WLAN_VENDOR_*` 宏 | `linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig:791,1320-1337` |
| hispark_phoenix | 仅 `CONFIG_CFG80211=y` + `MAC80211=m`，**无芯片驱动** | | `linux-5.10/arch/arm/configs/hispark_phoenix_standard_defconfig` |
| qemu virt (arm/arm64) | **`CONFIG_BRCMFMAC=m`**（QEMU 虚拟 e1000e/BCM 模拟） | `CFG80211=m`、`MAC80211=m` | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig:325`；`linux-5.10/qemu/arch/arm64_defconfig:325` |
| unionpi_tiger | **`CONFIG_RTL8821...`=y**（Realtek RTL8821 组合式，1 命中） | `CFG80211`/`MAC80211` 计数 = 0 | `linux-5.10/unionpi_tiger/arch/arm64_defconfig` |
| qemu loongarch64 | `MT76*`=m(1)、`RTL8821*`=y、`RTW88*`=y、`BCMDHD*`=m(1) | 9+3m | `linux-5.10/arch/loongarch/configs/qemu-loongarch64-linux_standard_defconfig` |

**全 35 个配置的芯片驱动普查（`=y` 或 `=m`）**：

| 驱动族 | 出现配置数 | 说明 |
|---|---|---|
| `BCMDHD` | 8 | rk3568(×2 版本×2 形式)、rk3399、yangfan(×2)、imx8mm(×2)、loongarch-qemu |
| `BRCMFMAC` | 3 | 仅 qemu arm/arm64 virt |
| `MT76*` | 1 | 仅 `linux-5.10/arch/loongarch/.../qemu-loongarch64-linux_standard_defconfig`（且为 `=m`） |
| **`MT7921` / `MTL*`（联发科）** | **0** | 全仓库无 |
| **`RTL8189*`** | **0** | 全仓库无 |
| `RTL8821*` / `RTW88*` | 各 1 | 仅 loongarch-qemu 与 unionpi_tiger |
| **`AW859A`（中科微 AW859A）** | **0** | 全仓库无 |
| **`UWE5622` / `AIC*` / `AICH*` / `ESP*` / `ZYDAS*` / `RTL8152`** | **0** | 全仓库无 |
| `BCM4343*` | 0 | 全仓库无（只有 `BCMDHD` 与 `BT_HCIBTUSB_BCM`） |

### 3.4 蓝牙

| 板型 | 启用的 HCI 驱动 | 行号（6.6/rk3568） |
|---|---|---|
| **rk3568 (dayu200)** | `BT_HCIBTUSB_BCM=y`（**BCM 43570/43540 USB HCI**，配合板级 `vendor_hihope/rk3568/bluetooth/BCM4362A2.hcd` 固件）、`BT_HCIBTUSB_RTL=y`、`BT_HCIUART_H4=y`、`BT_HCIUART_ATH3K=y`、`BT_HCIVHCI=y`、`BT_MRVL_SDIO=y`；协议 `BT_BREDR:908`、`BT_LE:912` | `:925,927,930,932,938,940,908,912` |
| 板级蓝牙固件证据 | `device_board_hihope:rk3568/ohos.build:8-9` 引 `//vendor/hihope/rk3568/bluetooth:libbt_vendor` 与 `BCM4362A2.hcd` | — |
| imx8mm | `BT_HCIBTUSB=m` + `BT_HCIUART` 系（BCSP/ATH3K/LL/3WIRE/BCM/QCA）+ `BT_HCIVHCI=y` | `linux-5.10/imx8mm/arch/arm64_defconfig:154,155-161,162` |
| hispark_taurus | **无 BT 符号**（BT 计数 0） | — |
| qemu virt arm/arm64 | `BT_HCIBTUSB=m` + `BT_HCIUART=m`（3+2m） | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig` |

### 3.5 摄像头 / ISP / 编解码

**rk3568（6.6 与 5.10 内容一致，行号 −2）：**

| 子系统 | 符号 | 行号(6.6) / 行号(5.10) |
|---|---|---|
| V4L2 框架 | `VIDEO_V4L2` / `_I2C` / `_SUBDEV_API` / `V4L2_MEM2MEM_DEV` / `V4L2_FWNODE` | 2729/2730/2731/2734/2735 ‖ 2727/2728/2729/2732/2733 |
| CIF | `VIDEO_ROCKCHIP_CIF` | 2835 ‖ 2833 |
| **ISP** | `VIDEO_ROCKCHIP_ISP` + `_VERSION_V1X`(2841) + `_V21`(2843) + `_V30`(2844) | 2840,2841,2843,2844 ‖ 2838,2839,2841,2842 |
| **ISPP** | `VIDEO_ROCKCHIP_ISPP` + `_VERSION_V20`(2848) | 2845,2848 ‖ 2843,2846 |
| **RGA** | `VIDEO_ROCKCHIP_RGA` | 2851 ‖ 2849 |
| **ISP 摄像头 sensor** | `VIDEO_GC8034`(galcore)、`VIDEO_OV5695`、`VIDEO_OV7251`、`VIDEO_OV13855`(omnivision) | 2974, 2993, 2994, 2995 ‖ 2972, 2991, 2992, 2993 |
| **硬编解码（MPP）** | `ROCKCHIP_MPP_RKVDEC`(3603)、`RKVDEC2`(3604)、`RKVENC`(3605)、`RKVENC2`(3606)、`VDPU1`(3607)、`VDPU2`(3609) | 3603-3609 ‖ 同区域 |
| HDMI 音频 | `DRM_DW_HDMI_I2S_AUDIO` | 3419 ‖ 3417 |

**其他板型：**
- **hispark_taurus**：仅 `MEDIA_SUPPORT:1880` / `MEDIA_CAMERA_SUPPORT:1889` / `VIDEO_V4L2:1897`（板级 camera pipeline 走 HDF 而非 V4L2）。**无 ISP、无 RGA、无硬编解码。**
- **hispark_phoenix**：**无任何摄像头/编解码符号。**
- **imx8mm / myd_imx8mm**：`VIDEO_V4L2=y`(1 命中) + 大量 `=m` 传感器；**无 ROCKCHIP_ISP / RGA / MPP**（非 RK 平台）。
- **unionpi_tiger**：`VIDEO_V4L2` 计数 = 0；`RGA` 有 1 个 `=m`。
- **qemu**：`VIDEO_V4L2` 计数 = 0（纯模拟板，无摄像头）。

### 3.6 其他板级关键外设

| 外设 | rk3568 (6.6) | rk3568 (5.10) | hispark_taurus (5.10) | imx8mm (5.10) | unionpi_tiger (5.10) | qemu virt arm64 |
|---|---|---|---|---|---|---|
| **MMC** | `MMC_DW_ROCKCHIP=y:4317`、`MMC_SDHCI=y:4296`、`MMC_CQHCI=y:4321`、`MMC_SDHCI_OF_DWCMSHC=y:4302` | `:4314, 4293, 4318, 4299` | `MMC=y:2500`、`MMC_BLOCK=y:2503`（**无板级 MMC 控制器驱动**） | `MMC_SDHCI=y` | 无 `MMC_DW_ROCKCHIP`；`MMC_SDHCI_OF_ARASYN` 系列 | `MMC_SDHCI=y` |
| **触摸** | **22 个 `TOUCHSCREEN_*` =y**，含 `ELAN:1846`、`ATMEL_MXT:1820`、USB 触摸 `EQUALAX/PANJIT/3M/ITM/ETURBO/GUNZE/DMC_TSC10/IRTOUCH/IDEALTEK/GENERAL_TOUCH/GOTOP/JASTEC/ELO/E2I/ZYTRONIC/ETT_TC45USB/NEXIO/EASYTOUCH` (1865-1880)；`INPUT_RK805_PWRKEY=y:1926` | 同上，行号 −2 | 无 TOUCHSCREEN | 16+2m | 23 | 11+9m |
| **按键** | `KEYBOARD_ADC=y:1770`、`KEYBOARD_GPIO=y:1779`、`KEYBOARD_GPIO_POLLED=y:1780`、`INPUT_RK805_PWRKEY=y:1926` | −2 | `KEYBOARD_ATKBD=y:1212` | — | — | — |
| **RTC** | `RTC_DRV_HYM8563=y:4399`（HYM8563）、`RTC_DRV_RK808=y:4401`（RK808 PMIC） | −2 | `RTC_DRV_HIBVT=y:2429`（海思 VBVT） | `RTC_DRV_HIBVT` | 5+1m | — |
| **PCIe** | `PCIE_ROCKCHIP=y:1020`、`PCIE_ROCKCHIP_HOST=y:1021`、`PCIE_DW=y:1026`、`PCIE_DW_ROCKCHIP=y`(5.10 为 `=m`:227) | 同 | **无** `PCIE_ROCKCHIP` | — | — | — |
| **USB** | `USB_DWC3` 计数 = 0（rk3568 用 DWC2 + USB2 PHY，见 `PHY_ROCKCHIP`）；`USB_XHCI_*`、`USB_STORAGE`、`USB_CONFIGFS_*` 全开 | 同 | **`USB_DWC3=y:2378` + `USB_DWC3_DUAL_ROLE=y:2381` + `TYPEC=y:2483`**（Hi3516DV300 用 DWC3 Type-C） | `USB_DWC3` 0 | 0 | `USB_DWC3=y`(6.6 qemu) |
| **以太网/PHY** | `STMMAC_ETH=y:1504`、`DWMAC_ROCKCHIP=y:1509`、`PHY_ROCKCHIP=y:1557`、`ROCKCHIP_PHY=y:381`(5.10 `:381`) | `:1502,1507,1555` | **无 GMAC**（Hi3516DV300 无网口或走外接 PHY） | `STMMAC_ETH=m:286` | `STMMAC_ETH=y:1529` | `STMMAC_ETH=m:296` |
| **温控** | `ROCKCHIP_THERMAL=y:2495` | `:2493` | 无 | `=m:473` | 无 | `=m:484` |
| **安全加固** | `CONFIG_HIDE_MEM_ADDRESS=y:6174`（**仅板级 `<board>/arch/*_defconfig` 形态有**，`arch/*/configs/*` 形态无） | `:6174` | 无 | 无 | 无 | 无 |
| **IOMMU** | `ROCKCHIP_IOMMU=y:4714` | `:4711` | 无 | `:842` | 无 | `:1484` |

---

## 4. 三个明确问题的回答

### Q1. **6.6.101 到底支持哪些设备？**

**答：只支持 2 类，共 3 个构建目标。逐条如下，没有第四个。**

`kernel_linux_6.6@OpenHarmony-7.0-Release` = 6.6.101（`Makefile: PATCHLEVEL=6, SUBLEVEL=101`）。
`kernel_linux_config@7.0` 的 `linux-6.6/` 目录**总共只有 7 个文件**（4 个板级配置 + `base_defconfig` + 2 个 `type/`）：

| 设备 | 6.6 配置路径 | 是否可用 | 备注 |
|---|---|---|---|
| **rk3568 / dayu200**（`hihope/rk3568`，及其 7 个衍生产品） | `linux-6.6/rk3568/arch/arm64_defconfig` | ✅ **主目标** | 6.6 的头号支持设备；机制 A 板级 `build_kernel.sh` |
| rk3568（`kernel.mk` 路径形态） | `linux-6.6/arch/arm64/configs/rk3568_standard_defconfig` | ✅ | 机制 B |
| **QEMU arm64 virt**（`arm64_virt` / `qemu-arm-linux`） | `linux-6.6/arch/arm64/configs/qemu-arm-linux_standard_defconfig` | ✅ | 机制 B |
| **QEMU arm virt** | `linux-6.6/arch/arm/configs/qemu-arm-linux_standard_defconfig` | ✅ | 机制 B |
| QEMU `linux_full`（`arm64_virt` / `x86_64_virt`） | 板内 `device/qemu/common/virt_full/kernel/{arm64_virt,arm_virt}_defconfig` | ✅ | 机制 E，`BUILD.gn:9` 硬编码 `//kernel/linux/linux-6.6` |

**6.6 明确不支持（6.6 配置仓里根本没有对应文件）：**
rk3588 / dayu210、hi3516DV300 (hispark_taurus)、hi3751V350 (hispark_phoenix)、
imx8mm、unionpi_tiger、yangfan、rk3399、QEMU x86_64 / riscv64 / loongarch64。

⚠️ 特别注意：**`x86_64_virt` 的 `linux_full` 产品用的是 6.6**（板级硬编码），但它的 *min* 产品若走机制 B 就无 6.6 配置可用 —— 机制 E 与机制 B 在同一产品族里给出不同内核版本，这是 7.0 的一处不一致。

### Q2. **6.6 和 5.10 各自的板型重叠与差异？**

**重叠（两个版本都有配置）——只有 2 项：**
1. **rk3568 / dayu200**（`linux-{5.10,6.6}/rk3568/arch/arm64_defconfig` + `arch/arm64/configs/rk3568_standard_defconfig`）
2. **QEMU arm / arm64 virt**（`arch/{arm,arm64}/configs/qemu-arm-linux_standard_defconfig`）

**5.10 独有：**
hispark_taurus (hi3516DV300)、hispark_phoenix (hi3751V350)、imx8mm / myd_imx8mm、
unionpi_tiger (RK3398)、yangfan (RK3568 模组)、rk3399、QEMU x86_64 / riscv64 / loongarch64。
以及 **4.19**（仅配置存在，内核仓已不在 7.0 manifest）。

**6.6 独有：无（除 rk3568 + qemu arm/arm64 之外 6.6 没有任何独占板型）。**

**结构性差异：**
- 配置文件数量：5.10 有 26 个 defconfig，6.6 只有 4 个 → **6.6 的板型覆盖面是 5.10 的约 1/6**。
- 形态覆盖：5.10 同时提供 `arch/*/configs/*`（机制 B，9 个）与 `<board>/arch/*`（机制 A，6 个）两种形态；
  6.6 两种形态都只有 rk3568 + qemu-arm-linux，**x86_64 / riscv64 / loongarch64 在 6.6 上完全没有 `arch/*/configs/*` 文件**。
- 安全加固模块：机制 B（`arch/*/configs/*`）在两个版本都**不**含 `CED / XPM / DEC / code_sign / hideaddr`，
  只有机制 A 的 `linux-5.10/rk3568/arch/arm64_defconfig:6174` 有 `CONFIG_HIDE_MEM_ADDRESS=y`。
  这与 `kernel_linux_build:kernel.mk:129-143` 中 `ifeq ($(KERNEL_VERSION), linux-6.6)` 才应用 CED/XPM/DEC 补丁的写法一致 ——
  **6.6 走的是"新式安全模块"，5.10 走的是"旧式"**。
- 全局默认：`build@7.0/ohos/kernel/kernel.gni:14` 默认 `linux-6.6`，且**全部 device/vendor 仓无 override**，
  所以"想用 5.10"必须由 `config.json` 的 `kernel_version` 或板级硬编码提供，否则默认落到 6.6。

### Q3. **哪些是 OHOS 7.0 真正出货的、有公开配置可编译的？哪些只是社区/实验性的？**

#### A. 真正出货，CI 门禁 + 公开配置齐备（可编译）✅

| 产品/板 | 内核 | 门禁形态 | 关键证据 |
|---|---|---|---|
| **dayu200 / rk3568**（`hihope/rk3568`，8 个产品共用） | 5.10.210 **与** 6.6.101 | `dayu200`, `TEST_dayu200`, `dayu200-codearts`, `dayu200_xts`, `dayu200_part` | `matrix_product.csv`：`kernel_linux_5.10`/`kernel_linux_6.6`/`device_board_hihope`/`device_soc_rockchip`/`vendor_hihope` 均在 `dayu200` = Y |
| **hispark_taurus Linux**（hi3516DV300） | 5.10.210 | `hispark_taurus_Linux`, `TEST_hispark_taurus_Linux` | `matrix_product.csv`：`kernel_linux_5.10`/`device_board_hisilicon`/`device_soc_hisilicon`/`vendor_hisilicon` 在该形态 = Y；`config.json:11` `"kernel_version":"5.10"` |
| **hispark_taurus LiteOS** | LiteOS-A 3.0 | `hispark_taurus_LiteOS` | `kernel_liteos_a`/`kernel_liteos_m` 在该形态 = Y |
| **hispark_pegasus**（hi3861v100） | LiteOS-M | `hispark_pegasus` | 同上 |
| **QEMU Linux**（`Emulator` + `arm64_virt`/`x86_64_virt` + `ohos-host`/`ohos-mini`） | 5.10.210（`Emulator` 仅 5.10 有 Y）与 6.6.101 | `Emulator`, `arm64_virt`, `x86_64_virt` | `matrix_product.csv`：`device_qemu`/`vendor_ohemu` 仅在 `Emulator` = Y；`kernel_linux_5.10` 含 `Emulator` 而 6.6 不含 |
| **LiteOS-M 板**：neptune100、nearlink_dk_3863、qemu `*_mini_system_demo` | LiteOS-M | `ohos-mini` | `device_board_hihope` 的 neptune100/nearlink_dk_3863 目录存在 |
| **hispark_aries** | LiteOS-A | `hispark_taurus_LiteOS` | 板目录存在 |

#### B. manifest 中声明但 **7.0 上不可构建** ❌

| 板/产品 | 问题 | 证据 |
|---|---|---|
| **wukong100（UNISOC p7885）** | 板/SoC/vendor 仓都在 manifest 里，但内核仓 **`kernel_unisoc_p7885` 不在 manifest 且 gitcode 404**。`wukong100/kernel/BUILD.gn:18-19` 硬依赖 `//kernel_unisoc_p7885` | `git ls-remote` → 403 `project could not be found`；API → 404 `Project not found`；`manifest/ohos.xml` + `chipsets/*/*.xml` grep `unisoc` 仅命中 `device_soc_unisoc` |
| **hispark_taurus_standard** | `config.json` **无 `kernel_version`** → 落回全局默认 `linux-6.6`，但 6.6 配置仓无 hispark defconfig。只有 `hispark_taurus_linux` / `_linux_ex`（显式 `"kernel_version":"5.10"`）可编译 | `vendor_hisilicon:hispark_taurus_standard/config.json` vs `hispark_taurus_linux/config.json:10-11` |
| **watchos（hi3516DV300, kernel 4.19）** | `"kernel_version":"4.19"`，但 **`kernel_linux_4.19` 不在 7.0 manifest**（7.0 只有 5.10 / 6.6 / liteos_a / liteos_m / uniproton） | `ohos/ohos.xml` kernel* 条目清单；`matrix_product.csv` 无 `watchos` 形态 |
| **hispark_phoenix（hi3751V350）** | 配置存在于 `linux-5.10/arch/arm/configs/`，但 `config.json` 无 `kernel_version` → 默认 6.6 无对应配置；且板内为**预编译 boot 镜像**（`linux/boot/{atf,uboot,slaveboot,logo,panel}.bin`），`kernel.mk:58-59,108` 对其特判 | `device_board_hisilicon:hispark_phoenix/linux/boot/` 全为 `.bin`；`vendor_hisilicon:hispark_phoenix/config.json` |

#### C. 只有配置、**无板无产品无门禁** —— 社区 / 移植预留 ⚠️

以下 4 组在 `kernel_linux_config@7.0` 有完整 defconfig，但在 7.0 **没有任何 `device/board/*` 板目录、
没有任何 `vendor/*/<product>` 产品、不在 `matrix_product.csv` 任何设备形态里**：

| 配置 | 形态 | 典型用途 |
|---|---|---|
| `linux-5.10/imx8mm/arch/arm64_defconfig`、`linux-5.10/arch/arm64/configs/myd_imx8mm_defconfig` | i.MX8M Mini | 第三方 BSP / `ohos-sdk` |
| `linux-5.10/unionpi_tiger/arch/arm64_defconfig`、`arch/arm64/configs/unionpi_tiger_standard_defconfig` | RK3398（香橙派 4B 同 SoC） | 第三方 BSP |
| `linux-5.10/yangfan/arch/arm64_defconfig` | RK3568 模组 | 第三方 BSP / ophub |
| `linux-5.10/arch/arm64/configs/rk3399_standard_defconfig` | RK3399 | 第三方 BSP |
| `linux-4.19/*`（4 个文件） | hi3516DV300 4.19 | 历史遗留 |
| `linux-5.10/hispark_taurus/arch/arm_defconfig`、`linux-5.10/qemu/arch/*_defconfig` | 板级形态（旧式） | 机制 A 遗留，与机制 B 并存 |

#### D. 任务假设中 7.0 **不存在**的板型（不要写进报告正文）

树莓派 4B（Raspberry Pi 4B）、香橙派 5Plus（Orange Pi 5 Plus）、香橙派 4B ——
**OpenHarmony 7.0 官方 manifest 与配置仓中均无**。
对 `manifest-OpenHarmony-7.0-Release/` 全目录 grep `rpi|raspberry|树莓|orangepi|香橙` 仅命中 `README.md:64` 的说明性举例文字。

---

## 5. 移植视角的几条硬事实（给 ohos-kernel-port 用）

1. **`build/ohos/kernel/kernel.gni:14` 的 `linux_kernel_version = "linux-6.6"` 是全局默认**，且 7.0 全树无 override。
   任何新板子若不显式指定，**默认会走 6.6**；而 6.6 在 OHOS 只有 rk3568 一套真实板级配置。
2. **6.6 板级配置形态（`linux-6.6/rk3568/arch/arm64_defconfig`）与 5.10 几乎逐行相同**（同一套 RK3568 BSP 移植到两个 LTS），
   5.10↔6.6 配置 diff 仅 1462 行 / 6193 行，含大量纯排序与注释差异，**实质符号差异很小**。
3. **`linux-6.6/` 只有 4 个板级配置** → 任何"6.6 支持新板"的需求，在 OHOS 上都必须由板子自带 defconfig
   （像 `dayu210` 那样，`dayu210/kernel/kernel_config/linux-5.10/arch/arm64/rk3588_standard_defconfig`），
   或像 `qemu virt_full` 那样自带 `configs/` 目录。
4. **5.10 与 6.6 的安全模块路径不同**（`kernel.mk:129` `ifeq ($(KERNEL_VERSION), linux-6.6)` 才打 CED/XPM/DEC/code_sign/hideaddr），
   移植时如果 5.10 路径没走 `common_modules`，缺的是这一整套。
5. **rk3568/dayu200 硬件画像固定为**：Mali-Bifrost GPU（且 MALI400/450 旧驱动与 BIFROST 同时 =y，两者共存）、
   BCM 蓝牙 HCI + BCMDHD WiFi（**无 cfg80211/mac80211**）、Rockchip ISP v1.x/2.1/3.0 + ISPP 2.0 + RGA + MPP RKVDEC/RKVENC/VDPU1/VDPU2、
   4 颗摄像头 sensor（GC8034 / OV5695 / OV7251 / OV13855）、**无 NPU**、RK808+HYM8563 RTC、22 个触摸驱动。
6. `device/board/hihope/rk3568/kernel/build_kernel.sh:54` `MAKE_OHOS_ENV="GPUDRIVER=mali"`，
   `:64-66` 支持 `enable_ramdisk` / `enable_mesa3d` 覆盖 → **Mesa3D 是备选 GPU 后端，6.6/5.10 配置里没有任何 `CONFIG_DRM_MESA*` 或 `CONFIG_MESA_*`，
   启用 mesa3d 会得到一个没有用户态匹配的组合**（`DRM_MALI_DISPLAY=y` 只出现在旧的 `oh7-defconfig.txt` / 5.10 老版本里，7.0 正式配置中已无）。

---

## 6. 调研方法与可复现命令

```bash
export GIT_SSL_CAINFO=/etc/ssl/certs/agent-identity/sandbox-gateway-ca.crt

# 1) manifest（已有只读 clone）
M=/workspace/ohos-kernel-port/.research/recon/manifests/manifest-OpenHarmony-7.0-Release
grep -E 'name="(kernel_linux[^"]*|productdefine_common|device_board[^"]*|device_soc[^"]*|vendor_[^"]*|device_qemu)"' \
     $M/ohos/ohos.xml $M/chipsets/*/*.xml

# 2) 配置仓 35 个 defconfig（blobless 部分克隆，按需取 blob）
git clone --filter=blob:none --no-checkout --depth=1 --single-branch \
     --branch OpenHarmony-7.0-Release \
     https://gitcode.com/openharmony/kernel_linux_config.git kcfg
git -C kcfg ls-tree -r --name-only origin/OpenHarmony-7.0-Release
for p in $(git -C kcfg ls-tree -r --name-only origin/OpenHarmony-7.0-Release | grep defconfig); do
  git -C kcfg show "origin/OpenHarmony-7.0-Release:$p" > "cfgs/$(echo $p|tr / _)"
done

# 3) 全局默认内核版本
git clone --filter=blob:none --no-checkout --depth=1 --single-branch \
     --branch OpenHarmony-7.0-Release https://gitcode.com/openharmony/build.git
git -C build show HEAD:ohos/kernel/kernel.gni     # → linux_kernel_version = "linux-6.6"

# 4) 板/产品仓（blobless，避免拉预编译大件）
for r in device_board_hihope device_board_hisilicon device_board_revoview device_qemu \
         vendor_hihope vendor_hisilicon vendor_revoview vendor_ohemu; do
  git clone --filter=blob:none --no-checkout --depth=1 --single-branch \
       --branch OpenHarmony-7.0-Release "https://gitcode.com/openharmony/$r.git"
done

# 5) 确认 wukong100 内核仓不存在
git ls-remote --heads https://gitcode.com/openharmony/kernel_unisoc_p7885.git   # 403
curl "https://api.gitcode.com/api/v5/repos/openharmony/kernel_unisoc_p7885"    # 404
```

> 注意事项：gitcode contents API（`api.gitcode.com/api/v5/...`）在密集并发下会返回 **HTTP 429 Too Many Requests**，
> 且 `contents/<path>` 对"不存在的文件"与"被限流"都可能出现 404/429 混淆。改用 `--filter=blob:none` 的部分克隆 + `git show`
> 按需取 blob 更稳（本次 35 个 defconfig 与 9 个板/产品仓全部由此方式取得）。
> **本调研未 clone 任何内核源码树或预编译大件**，只取了 `Makefile` 与配置文件。

---

## 7. 明确"未查到"的项

| 事项 | 状态 |
|---|---|
| 树莓派 4B / 香橙派 5Plus / 香橙派 4B 在 OHOS 7.0 的板定义 | **未查到**（7.0 manifest 与配置仓中均不存在） |
| `productdefine/common/*.json` 里的板级产品定义 | **未查到**（7.0 已改由 `vendor/*/config.json` 承担） |
| `config.json` 的 `kernel_version` 字段是否被 plumb 到 GN 的 `linux_kernel_version` | **未验证**（该转换逻辑不在 `build` 仓的 `.py`/`.gni` 中，我未找到消费点；不排除在 `build/hb` 或 CI 脚本中） |
| `hispark_aries` 对应的 `device/soc/hisilicon/<soc>` 目录 | **未查到**（`config.json` 未写 soc，`device_board_hisilicon/hispark_aries/ohos.build` 也未 import soc.gni） |
| `hcs/`、`shields/` 目录用途 | 已确认是 neptune100 的 LiteOS-M HCS 与 shield 选择（`shields/Kconfig.liteos_m.shields`、`shields/neptune100/Kconfig.liteos_m.shield:15-18` `config SHIELD_NEPTUNE100_EVB`），与 Linux 内核无关 |
| 6.6 上 RK3588 是否有任何配置（哪怕板级自带） | **未查到**（除 `dayu210` 的 5.10 板级 defconfig 外无） |
| `dayu600_7885_7.0_release` 对应的产品目录 | **未查到**（`vendor_hihope@7.0` 无 `dayu600`；判定为 CI bundle 名而非产品） |
