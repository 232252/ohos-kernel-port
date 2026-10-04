# GOAL — ohos-kernel-port

## 使命
把 [ophub/kernel](https://github.com/ophub/kernel) 的完整多内核构建 / 打包 / 维护体系迁移到 **OpenHarmony**，
以 **OpenHarmony 7.0 + Linux Kernel 6.6.101** 为主线目标，覆盖 ophub 支持的全部内核版本线，
以**开源工程**形式发布到 GitHub（账号 `232252`）。

## 交付物（Definition of Done）
1. **代码仓**：`ohos-kernel-port` GitHub 仓库，默认分支 `main`，公开可见。
2. **内核版本覆盖**：ophub 全部内核版本线（5.4 / 5.10 / 5.15 / 6.1 / 6.6 ...）× OpenHarmony，
   每条线都有可用的获取、配置、构建、打包脚本。
3. **主线 6.6.101**：与 OpenHarmony 社区 `kernel_linux_6.6` 的 6.6.101 对齐（版本号校验、defconfig、
   OHOS 特有配置片段、boot.img 打包）。
4. **OHOS 集成**：OpenHarmony 源码树内的接入方式（`kernel/linux/linux-6.6`、board 目录、
   `build.sh --build-target` 目标、out 产物落位）。
5. **CI**：GitHub Actions 在 arm64 runner 上真实构建 6.6.101，产出 `boot.img` / `Image` / `*.deb` 等产物。
6. **合规**（用户明确要求「注意开源的要求」）：
   - ophub/kernel 为 **GPL-2.0**；派生工作必须整体以 **GPL-2.0-only** 发布，
     不得改标 GPL-3.0、不得 dual-license、不得写 `-or-later`（GPL-2.0 §4 禁止 sublicense）。
   - 保留原作者版权声明与 GPL 文本；新增 `NOTICE` / `AUTHORS` / `THIRD_PARTY_LICENSES.md`。
   - 标注对 ophub 原仓的修改（GPL-2.0 **§2(a)** 要求标注改动与日期；
     注意 §5 没有子条款，终止条款是 §4 而非 §3，GPLv2 也没有商标条款）。
   - 不携带华为私有代码 / 非开源 prebuilts / 受限密钥。
7. **文档**：中英双语 README、构建指南、版本矩阵、移植说明、CI 产物使用说明。

## 关键事实（已核实）
- ophub/kernel 主分支 `main`，HEAD `27d66795`；许可为 **GPL-2.0**（LICENSE 18KB 全文已抓取）。
- OpenHarmony 社区 6.6 内核：6.6.101 存在于 `OpenHarmony-v6.0-Release` 分支
  （来源：gitcode.com/openharmony/kernel_linux_6.6，CSDN 移植记录佐证）。
- 沙箱环境：2 核 / 3 GB RAM → **无法**在此完成真机内核全量编译；编译交给 GitHub Actions runner。
- 沙箱 git 需 `http.sslCAInfo=/etc/ssl/certs/agent-identity/sandbox-gateway-ca.crt`（MITM 代理）。
- GitHub 账号 `232252`，环境内已注入 PAT（`$G`）。

## 风险与对策
| 风险 | 对策 |
| --- | --- |
| 2 核 3G 跑不动内核编译 | 本地只做脚本逻辑验证 + `make` 干跑；真实编译放 CI |
| ophub GPL-2.0 传染性污染 | 全仓 GPL-2.0，保留上游版权与改动标注 |
| OpenHarmony 7.0 社区分支可能尚未发布 | 双轨：7.0 分支优先，回落 6.0-Release + 标注 |
| 6.6.101 上 OHOS 补丁冲突 | 冲突点清单化，逐条处理并写进移植说明 |
| GitHub Actions 单次运行 6 小时上限 | 分架构矩阵化构建 + ccache |

## 修正记录（2026-10-04）
- **OpenHarmony 内核仓不止 4 个。** 早期按 `kernel_linux_<ver>` 命名规律猜测，
  漏掉了 `kernel_linux_config`（配置仓）、`kernel_linux_patches`（补丁仓）、
  `kernel_linux_build`（构建系统仓）。org 共 807 个仓，必须枚举 org 而不是猜命名。
- **in-tree defconfig 不是 OHOS 配置。** 实测仅覆盖 OHOS 所设 798 个符号中的
  110 个（13%），缺 `CONFIG_ACCESS_TOKENID`、`CONFIG_ANDROID_BINDER_IPC` 等。
  `kernel_linux_config` 是强制的。
- **OHOS 的 boot.img 不是 Android boot image。** 用 `mkbootimg` 产出的是
  点不亮的文件；OHOS 用自己的 `img_format` 格式，该工具仅存在于闭源 prebuilts。

## 里程碑
- **M1 侦察**：ophub 全量结构、OHOS 6.6 内核实况、许可边界。→ 产出 `docs/00-recon.md`
- **M2 骨架**：仓库初始化、目录布局、许可与文档骨架。→ 产出可用仓
- **M3 移植**：脚本改写为 OHOS 语义（取源/配置/构建/打包），版本矩阵铺开。
- **M4 主线打通**：6.6.101 + OpenHarmony 端到端脚本跑通（本地干跑 + CI 真编）。
- **M5 CI 与发布**：Actions、产物、Release、中英文档、发布到 GitHub。
