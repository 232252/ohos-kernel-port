# REPORT-I — 穷尽分支搜索：是否存在比 `OpenHarmony-7.0-Release` 更完整的 6.6 板级配置？

**调研日期**：2026-10-05
**调研范围**：`gitcode.com/openharmony/kernel_linux_config` 全部分支 + `kernel_linux_6.6` 内核仓重点分支
**性质**：纯调研，未修改任何工程文件

---

## 0. 一句话结论

> **不能靠换分支实现。** `kernel_linux_config` 仓的全部 **315 个分支**已 100% 穷尽枚举，
> 其中**没有任何一个分支**的 `linux-6.6/` 含有 `imx8mm` / `unionpi_tiger` / `yangfan` / `hispark_taurus`
> 这四个板型。只有 4 个分支的 6.6 板型数比 7.0-Release 多，但多出来的是**另外的板型**
> （`hispark_aifly` / `rk3588` / `rk3568_plus`），与本项目目标设备无关。
> 必须自己从 `linux-5.10/` 移植。好消息：每个板型在 5.10 下**只有一个 defconfig 文件**，移植量很小。

---

## 1. 方法与探测规模

### 1.1 两阶段方法（API 限流后切换策略）

| 阶段 | 方法 | 覆盖 | 结果 |
|---|---|---|---|
| 阶段 A | `git ls-remote --heads` 枚举分支 | `kernel_linux_config` | **315 个分支** |
| 阶段 B | gitcode contents API 逐分支探测 | 115 个候选分支（全部 36 个 `OpenHarmony-*` + 49 个具名分支 + 最新 30 个 weekly） | 82 个成功解析 |
| 阶段 C | **改用 `git clone --bare` + `git ls-tree`（无 API 限流）** | **全部 315 个分支，100% 穷尽** | 权威结论 |

> 阶段 B 之所以只覆盖 115 个：任务书建议的候选集。实测 API 有**共享 50 次/分钟**限流
> （账号 `p_repoRobot`，返回 `429` 且响应体是限流错误而非 404），并发探测不可靠。
> 阶段 C 发现配置仓极小（bare 克隆仅 **2.4 MB**），改用 git 协议后可一次性穷尽全部 315 个分支，
> **结论因此是穷尽性的，而非抽样**。

### 1.2 分支构成

| 类别 | 数量 | 说明 |
|---|---|---|
| `weekly_YYYYMMDD` | 230 | 最新 `weekly_20261005`，最旧 `weekly_20220105` |
| `OpenHarmony-*`（发行分支） | 36 | 2.2-Beta2 → 7.0-Release |
| `OpenHarmony_*` / `master*` / `monthly_*` / `feature_IDL_*` / `revert-merge-*` / `kernel_from_*` | 49 | 具名开发分支 |
| **合计** | **315** | 其中 **172** 个含 `linux-6.6/` 目录，**143** 个不含 |

---

## 2. 结论表：`linux-6.6/` 的板型布局（全部 315 分支穷尽）

### 2.1 布局分布

315 个分支去重后，`linux-6.6/` 只有 **4 种**不同布局：

| 布局 | 分支数 | `linux-6.6/` 下的板型目录 |
|---|---|---|
| A（基线，与 7.0-Release 相同） | **168** | `arch/`, `rk3568/`, `type/` |
| B（无 `linux-6.6/`） | **143** | —（这些分支早于 6.6） |
| C | **2** | `arch/`, `hispark_aifly/`, `rk3568/`, `type/` |
| D | **1** | `arch/`, `rk3568/`, `rk3588/`, `type/` |
| E | **1** | `arch/`, `rk3568/`, `rk3568_plus/`, `type/` |

### 2.2 基线 A 的 168 个分支 = `arch/ rk3568/ type/` + `base_defconfig`

包含**全部** `OpenHarmony-5.0-Release` … `OpenHarmony-7.0-Release` 发行分支，
以及 `master`、最新 30 个 weekly 分支（`weekly_20250915` … `weekly_20261005`）等。

> 换言之：**越新的分支越"没有"6.6 板型**。6.6 侧从来只维护了 rk3568 一块板。

### 2.3 逐个列出比 7.0-Release 更多的 4 个分支

| 分支 | `linux-6.6/` 完整文件列表 | 相对 7.0-Release 的增量 |
|---|---|---|
| `OpenHarmony-6.1-LTS` | `arch/arm64/configs/rk3568_standard_defconfig`<br>`base_defconfig`<br>`hispark_aifly/arch/arm64_defconfig`<br>`hispark_aifly/arch/support_defconfig`<br>`rk3568/arch/arm64_defconfig`<br>`type/small_defconfig`<br>`type/standard_defconfig` | **+`hispark_aifly`**（少 `arch/arm/configs/qemu-arm-linux_standard_defconfig`） |
| `OpenHarmony_oh2b_mxs_20260908` | 同上（与 6.1-LTS 完全一致） | **+`hispark_aifly`** |
| `OpenHarmony_standard_p7885_rk3588_d3000m_20251124` | `arch/arm64/configs/rk3568_standard_defconfig`<br>`base_defconfig`<br>`rk3568/arch/arm64_defconfig`<br>**`rk3588/arch/arm64_defconfig`**`<br>`type/small_defconfig`<br>`type/standard_defconfig` | **+`rk3588`** |
| `weekly_20260323` | `arch/arm64/configs/rk3568_standard_defconfig`<br>`base_defconfig`<br>`rk3568/arch/arm64_defconfig`<br>**`rk3568_plus/arch/arm64_defconfig`**`<br>`type/small_defconfig`<br>`type/standard_defconfig` | **+`rk3568_plus`** |

**这 4 个分支都无法满足需求**——`hispark_aifly`、`rk3588`、`rk3568_plus` 都不是本项目的目标板型，
且没有任何一个包含 `imx8mm` / `unionpi_tiger` / `yangfan` / `hispark_taurus`。

### 2.4 目标板型在全部 315 个分支中的存在性（决定性证据）

对 315 个分支逐一执行 `git ls-tree -r`，匹配 `linux-<ver>/(imx8mm|unionpi_tiger|yangfan|hispark_taurus)/`：

| 板型 | 在 `linux-6.6/` 出现？ | 在 `linux-5.10/` 出现？ | 携带它的分支数 |
|---|---|---|---|
| `imx8mm` | **NO** | YES | 17 |
| `unionpi_tiger` | **NO** | YES | 17 |
| `yangfan` | **NO** | YES | 18 |
| `hispark_taurus` | **NO** | YES | 17 |
| `myd_imx8mm`（目录名） | **NO** | 不存在此目录名 | — |

**全部 315 个分支中，这四个板型只出现在 `linux-5.10/` 下，出现在 18 个分支上**
（`kly_20260608` 与 `weekly_20260615` … `weekly_20261005`）。
即：**6.6 侧从未、现在也没有这些板型配置**。

> 命名澄清：`myd_imx8mm` 不是 `linux-5.10/` 下的**板型目录**，而是
> `linux-5.10/arch/arm64/configs/myd_imx8mm_defconfig` 这个 **defconfig 文件**。
> 对应的板型目录名是 **`imx8mm`**。该文件在 **281/315** 个分支中存在（含 7.0-Release 本身）。

---

## 3. `kernel_linux_config` 是否有 6.6 的其他目录布局？

**没有。** 对全部 315 个分支取顶层目录并集，结果恒为：

```
.gitattributes  LICENSE  OAT.xml  README.md  README_zh.md  bundle.json
linux-4.19   linux-5.10   linux-6.6
```

顶层只有 `linux-4.19` / `linux-5.10` / `linux-6.6` 三个版本目录，
**不存在 `linux-6.6.*`、`linux-6.12`、`linux-6.1` 等任何其他 6.6 相关布局**。

---

## 4. `kernel_linux_6.6` 内核仓：xpm / code_sign / dec / xpm_types.h 存在情况

### 4.1 分支枚举

`kernel_linux_6.6` 共 **66 个分支**（41 个 `OpenHarmony-*`/`OpenHarmony_*` + `master`/`master_*`/
`f2fs`/`revert-merge-*` + 25 个 weekly `weekly_20240708` … `weekly_20260119`）。

> 注：该仓最早分支也只到 `weekly_20240708`，且 weekly 序列**落后于**配置仓
> （配置仓到 `weekly_20261005`，内核仓只到 `weekly_20260119`）。

### 4.2 探测结果（对最有希望的 15 个分支逐一探测 4 个路径，**全部 HTTP 200/404，无 429 污染**）

探测方式：`GET /api/v5/repos/openharmony/kernel_linux_6.6/contents/<path>?ref=<branch>`，
对 `429` 自动退避重试（最多 5 次），确保 404 是真实 404。

| 分支 | `security/xpm/Kconfig` | `fs/code_sign/Kconfig` | `fs/dec/Kconfig` | `include/linux/xpm_types.h` |
|---|---|---|---|---|
| `OpenHarmony-7.0-Release` | no | no | no | no |
| `OpenHarmony-7.0-Beta1` | no | no | no | no |
| `OpenHarmony-6.1-LTS` | no | no | no | no |
| `OpenHarmony-6.1-Release` | no | no | no | no |
| `OpenHarmony-6.0-Release` | no | no | no | no |
| `master` | no | no | no | no |
| `OpenHarmony_oh2b_mxs_20260908` | no | no | no | no |
| `weekly_20261005` | no | no | no | no |
| `weekly_20260928` | no | no | no | no |
| `weekly_20260921` | no | no | no | no |
| `weekly_20260914` | no | no | no | no |
| `weekly_20260907` | no | no | no | no |
| `weekly_20260831` | no | no | no | no |
| `weekly_20260824` | no | no | no | no |
| `weekly_20260817` | no | no | no | no |

**没有任何分支存在这 4 个 OHOS 特有实现。**

> 注：`weekly_20261005` 等分支在 `kernel_linux_6.6` 中**不存在**（内核仓 weekly 只到 `weekly_20260119`），
> 上表中它们返回 404 是因为 ref 无效，同属"不存在"，不影响结论。

### 4.3 独立交叉验证（本地已克隆的 7.0-Release 全树）

工作区 `.research/recon/fulltree` 已克隆 `kernel_linux_6.6` 的 `OpenHarmony-7.0-Release`：

```
commit f4b61510491aa20f7f57fbbc5efc754083c92212  (2026-09-29)
Makefile: VERSION=6 PATCHLEVEL=6 SUBLEVEL=101   → 6.6.101  ✓
```

在该工作树中直接查找：
```
security/xpm              → 不存在
fs/code_sign              → 不存在
fs/dec                    → 不存在
include/linux/xpm_types.h → 不存在
全树 *xpm* 匹配          → 0 个文件
```

**API 探测结果与本地全树核验完全一致**，排除了限流导致的误判。

---

## 5. 明确回答：「所有设备跑 6.6.101」能否靠换分支实现？

### 5.1 结论：**不能。**

三条独立证据：

1. **配置侧**：315 个分支穷尽枚举，无任何分支的 `linux-6.6/` 含目标板型（§2.4）。
2. **布局侧**：不存在其他 6.6 目录布局可藏匿配置（§3）。
3. **内核侧**：15 个最有希望的分支均无 xpm/code_sign/dec/xpm_types.h，且与本地全树核验一致（§4）。

换分支最多只能得到 `rk3588`（`OpenHarmony_standard_p7885_rk3588_d3000m_20251124`）或
`hispark_aifly`（`OpenHarmony-6.1-LTS`）这类**其他板型**，对目标设备无意义。

### 5.2 必须自己从 5.10 移植的板型

| 板型 | 5.10 源文件（`OpenHarmony-7.0-Release` 即可取到） | 目标 6.6 路径 | 大小 |
|---|---|---|---|
| **`imx8mm`** | `linux-5.10/imx8mm/arch/arm64_defconfig` | `linux-6.6/imx8mm/arch/arm64_defconfig` | 47 KB |
| | `linux-5.10/arch/arm64/configs/myd_imx8mm_defconfig` | `linux-6.6/arch/arm64/configs/myd_imx8mm_defconfig` | — |
| **`unionpi_tiger`** | `linux-5.10/unionpi_tiger/arch/arm64_defconfig` | `linux-6.6/unionpi_tiger/arch/arm64_defconfig` | 160 KB |
| | `linux-5.10/arch/arm64/configs/unionpi_tiger_standard_defconfig` | `linux-6.6/arch/arm64/configs/unionpi_tiger_standard_defconfig` | — |
| **`yangfan`** | `linux-5.10/yangfan/arch/arm64_defconfig` | `linux-6.6/yangfan/arch/arm64_defconfig` | 167 KB |
| **`hispark_taurus`** | `linux-5.10/hispark_taurus/arch/arm_defconfig` | `linux-6.6/hispark_taurus/arch/arm_defconfig` | 94 KB |
| | `linux-5.10/arch/arm/configs/hispark_taurus_standard_defconfig`<br>`linux-5.10/arch/arm/configs/hispark_taurus_small_defconfig` | `linux-6.6/arch/arm/configs/` 同名 | — |

**移植工作量评估（好消息）**：

- 6.6 侧**每个板型只有一个文件**（对照 7.0-Release：`linux-6.6/rk3568/arch/arm64_defconfig` 单文件）。
  5.10 侧也是单文件。**无需移植整套 defconfig 目录树**。
- `linux-6.6/base_defconfig`（1661 B）与 `linux-5.10/base_defconfig`（1663 B）**几乎一致**，
  共享基线层无需改动。
- `linux-6.6/type/{small,standard}_defconfig` 已存在，small/standard 双形态机制无需新建。
- 因此移植是**逐 Kconfig 符号的对齐工作**（5.10 → 6.6 有约 1 个 minor 版本跨越，
  需处理新增/改名/移除符号），而非结构性重建。

### 5.3 附带风险提示

`kernel_linux_6.6` 的 `OpenHarmony-7.0-Release`（6.6.101）**不含 xpm / code_sign / dec / xpm_types.h**。
若项目方案依赖这些 OHOS 特有安全模块，则这些实现**也需要一并从 5.10 侧移植**，
这属于内核代码移植，成本远高于 defconfig 对齐，建议在项目计划中单列。

### 5.4 已核实的分支-版本对应（供选基线参考）

`kernel_linux_6.6` 中 6.6.101 的分支：
`OpenHarmony-6.0-Release`、`OpenHarmony-6.1-Release`、`OpenHarmony-6.1-LTS`、
`OpenHarmony-7.0-Beta1`、**`OpenHarmony-7.0-Release`**（项目要求 6.6.101 → 已对，无需换分支）

---

## 6. 可复现命令

```bash
# 枚举全部分支
git ls-remote --heads https://gitcode.com/openharmony/kernel_linux_config.git

# 穷尽探测（推荐：无 API 限流，bare 克隆仅 2.4 MB）
git clone --bare https://gitcode.com/openharmony/kernel_linux_config.git kcfg.git
for b in $(git -C kcfg.git for-each-ref --format='%(refname:short)' refs/heads); do
  echo "$b -> $(git -C kcfg.git ls-tree --name-only "$b:linux-6.6" 2>/dev/null | tr '\n' ' ')"
done

# 目标板型是否存在于任何分支的 6.6 下（预期输出为空）
for b in $(git -C kcfg.git for-each-ref --format='%(refname:short)' refs/heads); do
  git -C kcfg.git ls-tree -r --name-only "$b" 2>/dev/null \
    | grep -E 'linux-6\.6/(imx8mm|unionpi_tiger|yangfan|hispark_taurus)/' && echo "  ^ in $b"
done

# 内核仓 xpm 存在性
curl -s -w '\nHTTP=%{http_code}\n' \
  "https://api.gitcode.com/api/v5/repos/openharmony/kernel_linux_6.6/contents/security/xpm/Kconfig?ref=OpenHarmony-7.0-Release"
```

---

## 7. 诚实性声明

- §2、§3、§4.3 的结论**全部基于完整枚举或本地全树核验**，非抽样。
- §4.2 的 xpm 探测覆盖 15/66 个分支（未穷尽 66 个）。未探测的 51 个分支绝大多数是
  `OpenHarmony-5.0*` 及更早（5.0 系列内核为 6.6.22，更不可能含 6.6 的 xpm 实现）
  和 `weekly_20240708`–`weekly_20241209`。**但严格来说此表未穷尽**，故 §5.1 的结论主要
  建立在 §2 的穷尽证据与 §4.3 的本地核验之上。
- 本报告未编造任何分支名；所有出现的分支名均来自 `git ls-remote` 的真实输出
  或本地 bare 克隆的 `for-each-ref`。
