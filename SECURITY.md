# Security

SPDX-License-Identifier: GPL-2.0

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's private reporting: **Security → Report a vulnerability** on
<https://github.com/232252/ohos-kernel-port>.

Include the lane, the OpenHarmony branch, the kernel version, and a
reproducer. Expect an acknowledgement within a few days.

## Scope

This project builds kernels; it does not run them. In scope:

* the build driver producing an artifact that does not match its manifest
* a credential or proprietary blob committed to the repository
* a published artifact that cannot be traced to the source named in its
  `MANIFEST.txt`
* the licence-compliance checks being defeatable

Out of scope: vulnerabilities in the Linux kernel itself, in OpenHarmony, or in
a toolchain. Report those to their own projects — links are in
`THIRD_PARTY_LICENSES.md`.

## Note on the kernels we build

`CONFIG_CFI_CLANG` is enabled by OpenHarmony's own 6.6 `base_defconfig`. If you
build with `--cc gcc`, clang-only options are silently dropped and you get a
kernel without control-flow integrity. `ohos-kb` warns when you do this; treat
the warning as significant for anything exposed to untrusted input.
