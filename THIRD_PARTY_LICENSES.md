# Third-party licences

SPDX-License-Identifier: GPL-2.0-only

Every component whose code, configuration data, patch or binary this project
redistributes, links against, or builds against is listed here.

Licences are quoted in their canonical SPDX form. Where a repository's licence
file could not be read directly, the evidence used is stated in the Evidence
column; entries marked **UNVERIFIED** must not be treated as settled.

## 1. Source components

| Component | Version / commit | Source | Licence (SPDX) | Shipped in artifacts | Evidence |
| --- | --- | --- | --- | --- | --- |
| ophub/kernel | `27d66795` (2026-10-04) | https://github.com/ophub/kernel | `GPL-2.0-only` | no (build scripts adapted) | LICENSE 18092 B, md5 `b234ee4d…`; GitHub API `GPL-2.0` |
| ophub/amlogic-s9xxx-armbian | see MANIFEST | https://github.com/ophub/amlogic-s9xxx-armbian | `GPL-2.0-only` | no (approach adapted) | GitHub API `GPL-2.0` |
| unifreq/linux-6.6.y | branch tip | https://github.com/unifreq/linux-6.6.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | `Makefile` line 1 SPDX; `COPYING` says "version 2 only" |
| unifreq/linux-5.10.y | branch tip | https://github.com/unifreq/linux-5.10.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-5.15.y | branch tip | https://github.com/unifreq/linux-5.15.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-6.1.y | branch tip | https://github.com/unifreq/linux-6.1.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-6.12.y | branch tip | https://github.com/unifreq/linux-6.12.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-6.18.y | branch tip | https://github.com/unifreq/linux-6.18.y | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-5.10.y-rk35xx | branch tip | https://github.com/unifreq/linux-5.10.y-rk35xx | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| unifreq/linux-6.1.y-rockchip | branch tip | https://github.com/unifreq/linux-6.1.y-rockchip | `GPL-2.0-only WITH Linux-syscall-note` | builds into artifacts | as above |
| OpenHarmony kernel_linux_6.6 | branch tip (e.g. `f4b61510` for 7.0-Release) | https://gitcode.com/openharmony/kernel_linux_6.6 | `GPL-2.0-only` | builds into artifacts | `Makefile` line 1 `# SPDX-License-Identifier: GPL-2.0` |
| OpenHarmony kernel_linux_5.10 | branch tip | https://gitcode.com/openharmony/kernel_linux_5.10 | `GPL-2.0-only` | builds into artifacts | as above |
| OpenHarmony kernel_linux_4.19 / kernel_linux | branch tip | https://gitcode.com/openharmony/ | `GPL-2.0-only` | builds into artifacts | as above |
| OpenHarmony kernel_linux_config | `OpenHarmony-7.0-Release` | https://gitcode.com/openharmony/kernel_linux_config | see repository LICENSE | configuration data only | repository file listing |
| OpenHarmony kernel_linux_patches | `OpenHarmony-7.0-Release` | https://gitcode.com/openharmony/kernel_linux_patches | see repository LICENSE | not applied by default | repository file listing |
| OpenHarmony kernel_linux_build | `OpenHarmony-7.0-Release` | https://gitcode.com/openharmony/kernel_linux_build | see repository LICENSE | invoked, not vendored | repository file listing |

### Note on the `Linux-syscall-note` exception

`GPL-2.0 WITH Linux-syscall-note` is an *exception*, not an upgrade. It exempts
user-space programs that use the kernel only through system calls from being
subjected to the kernel's GPL. It does not change the base licence and does not
conflict with this project's GPL-2.0-only distribution.

### Note on non-GPL files inside kernel trees

Kernel trees contain files under permissive licences (BSD-2-Clause, BSD-3-Clause,
MIT) — for example parts of `net/`, some firmware metadata, and files under
`tools/lib/` and `tools/testing/`. **Any file copied directly out of a kernel
tree keeps the licence declared in its own header.** This project does not
relicense such files.

## 2. Build-time tools (not redistributed)

These are downloaded by CI at build time. They are **not** vendored into this
repository and **not** embedded into published artifacts.

| Tool | Licence | Note |
| --- | --- | --- |
| OpenHarmony prebuilt LLVM/Clang | `Apache-2.0 WITH LLVM-exception` | The exception covers output of the compiler, so linking it against a `GPL-2.0-only` kernel does not change that kernel's licence. |
| aarch64-linux-gnu-gcc (GCC) | `GPL-3.0-or-later WITH GCC-exception-3.1` | The GCC Runtime Library Exception exempts output, so it can build a `GPL-2.0-only` kernel. The `libstdc++` runtime itself must not be statically linked into a GPL-2.0-only artifact. |
| GNU Make | `GPL-3.0-or-later` | Build-time only. |
| GNU coreutils / findutils / grep / sed | `GPL-3.0-or-later` | Build-time only. |
| ccache | `GPL-3.0-or-later` | Build-time only. |
| GNU bash | `GPL-3.0-or-later` | Build-time only. |
| kmod (modinfo) | `GPL-2.0-only` | Build-time only; used to verify module licences. |
| mkbootimg (Android/OpenHarmony) | `Apache-2.0` | **Invoked as an external tool. Its source is deliberately NOT copied into this GPL-2.0-only repository, because Apache-2.0 and GPL-2.0-only are incompatible** (see GPL-2.0 section 2 final paragraph on mere aggregation). |
| zstd / xz / gzip | `GPL-2.0-or-later` / `GPL-2.0-only` | Build-time only. |

## 3. Deliberately excluded

The following must never be committed to this repository or placed in a
published artifact:

| Category | Reason |
| --- | --- |
| Huawei / OpenHarmony proprietary prebuilt binaries | Not open source. Embedding them would make them "accompany the executable" under GPL-2.0 section 3, transferring their licence obligations onto this project. |
| Vendor firmware blobs (Wi-Fi / Bluetooth / ISP) | Usually proprietary. |
| Release signing keys, tokens, certificates | Credential leakage. |
| `*.har`, `*.ohpm` | Closed distribution artefacts. |

## 4. Compatibility constraints

* **Apache-2.0 and GPL-2.0-only are incompatible.** Apache-2.0 code must not be
  copied into this repository, and GPL-2.0 code must not be moved into an
  Apache-2.0 work. They may only be *aggregated* — kept as separate files that
  are not derived from one another — which GPL-2.0's final paragraph of
  section 2 permits. That is why `mkbootimg` and OpenHarmony's `build.sh` are
  invoked as external tools rather than vendored.
* **GPL-2.0 §4 prohibits sublicensing.** This project therefore cannot be
  relicensed as GPL-3.0, nor dual-licensed. A `GPL-2.0-or-later` SPDX header on
  a derived file would be an unauthorised relaxation and a violation.
* **GPL-2.0 §8 forbids geographic distribution restrictions**, so this
  repository must remain publicly accessible everywhere it is published.

## 5. Review checklist (run before any release)

```bash
# LICENSE must be the verbatim FSF text
md5sum LICENSE   # b234ee4d69f5fce4486a80fdaf4a4263

# no patch may delete an SPDX header
grep -rn '^-.*SPDX-License-Identifier' patches/ && echo "FAIL" || echo "ok"

# every distributed module must declare GPL
find artifacts -name '*.ko' -exec modinfo -F license {} \; | sort -u

# no credentials
git ls-files -z | xargs -0 grep -lIE '(ghp_|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})' || echo "ok"

# no derived file may claim -or-later
git ls-files -z | xargs -0 grep -nE 'SPDX-License-Identifier:.*or-later' || echo "ok"
```

## 6. Items requiring legal review

This file is engineering documentation, not legal advice. The following were
flagged during review and remain open:

1. Whether an SPDX line plus git history alone satisfies GPL-2.0 section 2(a)
   for files that were only relocated rather than rewritten. This project takes
   the conservative route and adds a `Changes:` block to rewritten files.
2. Whether the repository name `ohos-kernel-port` and the use of the word
   "OHOS" in it fall inside the OpenAtom Foundation brand guide's "written
   permission required" list, or within its fair-descriptive-use allowance.
3. Whether toolchain runtime-library exceptions are interpreted identically in
   the target jurisdictions.
4. Whether a CLA is needed in addition to DCO to keep the authorisation chain
   unbroken for external contributors.
