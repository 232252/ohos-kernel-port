# GPL-2.0 compliance

SPDX-License-Identifier: GPL-2.0

This records what this project does to stay compliant, and where the checks
live. It is engineering documentation, not legal advice; items marked *needs
legal review* are genuinely open.

## The licence is not a choice

`ohos-kernel-port` is a derivative of [ophub/kernel](https://github.com/ophub/kernel)
(GPL-2.0) and builds on Linux kernel sources licensed
`GPL-2.0 WITH Linux-syscall-note`. GPL-2.0 §2(b) requires a distributed
derivative to be licensed as a whole under the same terms, and §4 forbids
sublicensing. Every link in the chain is GPL-2.0, so there is no permissive
exit.

Two consequences worth stating because they are easy to get wrong:

* **Not GPL-3.0.** The kernel trees say "version 2 only". GPL-2.0 §9 says only
  that the FSF may publish new versions; it does not let a downstream choose v3.
  The "or, at your option, any later version" option exists in GPLv3 §14, not in
  GPLv2.
* **Not dual-licensed.** That needs the agreement of every copyright holder,
  which spans ophub, unifreq and several thousand kernel contributors.

## Obligations, and where they are met

| GPL-2.0 clause | obligation | how this project meets it |
| --- | --- | --- |
| §1 | every copy carries the copyright notice, the warranty disclaimer and a copy of the licence | `LICENSE` is the verbatim FSF text (md5 `b234ee4d69f5fce4486a80fdaf4a4263`); `NOTICE` carries attribution and the disclaimer |
| §2(a) | modified files must state what changed and when | `Changes:` block in every file header; `NOTICE` lists the substantive changes; patch headers carry their own notes |
| §2(b) | the whole derivative is licensed under this licence | this repository is GPL-2.0-only throughout |
| §2 final ¶ | mere aggregation is allowed | Apache-2.0 `mkbootimg` and OpenHarmony's `build.sh` are **invoked**, never vendored — see below |
| §3 | source must accompany object code, or be offered from the same place | public repository is the designated place; every artifact ships a `MANIFEST.txt` naming the exact source commit, and releases pair with a source tag |
| §4 | no sublicensing | no `-or-later`, no dual-licence; CI asserts this |
| §6 | no additional restrictions on recipients' rights | `NOTICE` imposes none |
| §8 | no geographic distribution restrictions | the repository stays public |

## Automated checks

`ci/kernel-config-check.yml` fails a pull request if:

* `md5sum LICENSE` is not the verbatim GPL-2.0 text
* a patch under `patches/` removes an `SPDX-License-Identifier` line
* any tracked file claims `SPDX-License-Identifier: ...or-later`
* any tracked file contains a credential
* a resolved kernel configuration is missing `CONFIG_ACCESS_TOKENID` or
  `CONFIG_ANDROID_BINDER_IPC` (which would mean the OpenHarmony configuration
  was not applied — see [PORTING-NOTES.md](PORTING-NOTES.md))

`tests/run-tests.sh` re-checks the licence digest, the absence of `-or-later`,
and the presence of SPDX identifiers on every source file, on every run.

## Artifacts and §3

A `boot.img`, `Image` or `*.ko` published in a release is object code, so §3
applies. This project satisfies §3 through the *designated place* rule: the
public repository is the place, and the source is available from that same
place.

Concretely, every artifact directory contains a `MANIFEST.txt` recording:

* the kernel repository and its URL
* the OpenHarmony branch
* the exact source commit SHA
* the toolchain used
* the lane, system type and board

and releases should be published alongside a source tag
(`v<version>-src`) so the corresponding source is reachable from the same
repository. The §3(b) written-offer route is deliberately not used: it requires
maintaining an offer valid for three years, and the designated-place route is
both simpler and more useful to downstream.

The §3 "major components" exception covers the cross toolchain: a compiler is
normally distributed with the operating system, so it does not have to
accompany the binary. **But** once a component accompanies the executable, its
licence obligations attach to you. So toolchains are downloaded at build time
and never embedded in a `boot.img`, and no Huawei or OpenHarmony proprietary
prebuilt is ever placed in a published artifact.

## Apache-2.0 and the aggregation rule

`mkbootimg` is Apache-2.0. Apache-2.0 is incompatible with GPL-2.0-only.
Copying it into this repository would be a violation, so it is not copied: it
is invoked as an external tool. The same applies to OpenHarmony's `build.sh`
and the rest of its Apache-2.0 tree — this project drives the OpenHarmony build
system from outside rather than forking it in.

## Trademarks

GPL-2.0 contains no trademark clause; that arrived in GPLv3 §7. The
constraints here come from ordinary trademark law and from the OpenAtom
Foundation's public brand guide. `NOTICE` carries the disclaimer, and this
project reproduces no third-party logo or brand identifier. Descriptive use of
"OpenHarmony" in prose is kept factual and non-prominent.

## Open items — needs legal review

1. Whether an SPDX line plus git history alone satisfies §2(a) for files that
   were relocated rather than rewritten. This project takes the conservative
   route and adds a `Changes:` block to rewritten files.
2. Whether the repository name and the use of "OHOS" within it fall inside the
   brand guide's written-permission list or within its fair-use allowance.
3. Whether toolchain runtime-library exceptions are interpreted identically in
   the target jurisdictions.
4. Whether a CLA is needed in addition to DCO to keep the authorisation chain
   unbroken for external contributors.

See [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md) for the per-component
licence table and [templates/](https://github.com/232252/ohos-kernel-port/tree/main/templates)
for the file headers.
