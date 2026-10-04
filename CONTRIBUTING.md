# Contributing

SPDX-License-Identifier: GPL-2.0

Thanks for looking at this. A few things make contributions here straightforward
rather than bureaucratic.

## Sign-off is required

```bash
git commit -s
```

That adds a `Signed-off-by:` trailer. It records that you have the right to
contribute the change under this project's licence, and it keeps the GPL-2.0
authorisation chain unbroken. Pull requests without sign-off cannot be merged.

By contributing you agree that your contribution is licensed under
**GPL-2.0-only**, the same terms as the rest of the project.

## Mark your changes

GPL-2.0 §2(a) requires modified files to carry prominent notices stating what
changed and when. Concretely:

* Update the `Changes:` block in the file header of anything you rewrite.
* Add a new file with the standard header — see
  [templates/FILE_HEADER.template](templates/FILE_HEADER.template).
* If a patch under `patches/` changes the kernel, say so in the patch's own
  header comment.

Never remove an existing `SPDX-License-Identifier` line, and never add
`or-later`. GPL-2.0 §4 forbids sublicensing, so an `or-later` marker on a
derived file is an unauthorised relaxation. CI checks for this.

## What is worth changing

* **A lane** — `data/ohos-kernel-lanes.tsv`. Run `./ohos-kb verify` afterwards
  to confirm the version you recorded matches the remote.
* **A config delta** — `configs/lanes/<overlay>/`. Add a fragment only when you
  mean to change OpenHarmony's behaviour, and say why in a comment. A fragment
  that restates an OpenHarmony default will rot.
* **A patch** — `patches/`. `common-kernel-patches/` applies to every lane;
  `linux-<series>.y/` applies to that series only.
* **The driver** — `scripts/lib/*` and `ohos-kb`.

## Before you open a pull request

```bash
./tests/run-tests.sh      # 39 assertions, a few seconds, no network
./ohos-kb verify          # matrix vs. the remotes
./ohos-kb doctor
```

`ci/kernel-config-check.yml` runs the first of these on every pull request, plus
a licence check and a matrix-drift check.

## House style

* Bash, `set -euo pipefail`, `shellcheck` clean.
* Comments explain **why**, not what. A comment that restates the code is noise.
* Every claim about OpenHarmony should be traceable to a file, a branch, or a
  measurement. If you could not verify something, write "unverified" rather
  than rounding up to certainty — the difference has already mattered here.
* `printf` to stderr for logs, stdout for data. Scripts compose.

## Reporting bugs

Open an issue with the lane, the OpenHarmony branch, the kernel version, what
you expected, and what happened. `ohos-kb show <lane>` prints most of what is
needed.

Security issues: see [SECURITY.md](SECURITY.md).
