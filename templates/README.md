# Templates

SPDX-License-Identifier: GPL-2.0

`FILE_HEADER.template` is the header every new script and library in this
repository should carry.

Two rules matter beyond the boilerplate:

* **`GPL-2.0-only`, never `-or-later`.** GPL-2.0 §4 forbids sublicensing, and
  the whole chain (ophub, the Linux kernel) is GPL-2.0-only. An `or-later`
  marker on a derived file is an unauthorised relaxation; CI rejects it.
* **A `Changes:` line, with a date.** GPL-2.0 §2(a) requires modified files to
  carry prominent notices stating what changed and when.

When a file is derived from ophub, keep the upstream copyright lines. When it
is new, do not claim authorship you do not have.
