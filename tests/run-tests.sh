#!/bin/bash
#=======================================================================
# ohos-kernel-port / tests/run-tests.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Self-tests for the build driver's pure logic.  These run in seconds and need
# no kernel tree, no toolchain and no network, so CI can gate every pull
# request on them.  End-to-end compilation is covered by ci/build-kernel.yml
# instead.
#
# Usage: tests/run-tests.sh
#=======================================================================

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)

# shellcheck source=../scripts/lib/common.sh
source "${ROOT}/scripts/lib/common.sh"
# shellcheck source=../scripts/lib/matrix.sh
source "${ROOT}/scripts/lib/matrix.sh"
# shellcheck source=../scripts/lib/patch.sh
source "${ROOT}/scripts/lib/patch.sh"
# shellcheck source=../scripts/lib/config.sh
source "${ROOT}/scripts/lib/config.sh"

PASS=0; FAIL=0; SKIP=0
declare -a FAILURES=()

# assert_eq <label> <expected> <actual>
assert_eq() {
    local label=$1 want=$2 got=$3
    if [[ "${want}" == "${got}" ]]; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s\n' "${label}"
    else
        FAIL=$((FAIL+1)); FAILURES+=("${label}: expected '${want}', got '${got}'")
        printf '  \033[0;31mFAIL\033[0m %s\n        expected: %s\n        actual:   %s\n' "${label}" "${want}" "${got}"
    fi
}
assert_true() {
    local label=$1; shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s\n' "${label}"
    else
        FAIL=$((FAIL+1)); FAILURES+=("${label}: command failed: $*")
        printf '  \033[0;31mFAIL\033[0m %s\n        command: %s\n' "${label}" "$*"
    fi
}
assert_contains() {
    local label=$1 haystack=$2 needle=$3
    if [[ "${haystack}" == *"${needle}"* ]]; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s\n' "${label}"
    else
        FAIL=$((FAIL+1)); FAILURES+=("${label}: output did not contain '${needle}'")
        printf '  \033[0;31mFAIL\033[0m %s\n        looked for: %s\n        in: %s\n' "${label}" "${needle}" "${haystack}"
    fi
}
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

#==============================================================================
section "lane matrix integrity"
#==============================================================================

# Every row must have all nine fields populated, and a legal status.
bad_rows=0
while IFS=$'\t' read -r id kind repo host branch kver overlay status note; do
    [[ -z "${id}" || "${id}" == \#* ]] && continue
    for f in id kind repo host kver overlay status; do
        v=${!f}
        [[ -n "${v}" ]] || { printf '  row %s: empty %s\n' "${id}" "${f}"; bad_rows=$((bad_rows+1)); }
    done
    case "${status}" in
        primary|stable|legacy|experimental) ;;
        *) printf '  row %s: illegal status "%s"\n' "${id}" "${status}"; bad_rows=$((bad_rows+1)) ;;
    esac
    # an ohos lane must name a branch; an upstream lane must not claim one
    if [[ "${kind}" == "ohos" && "${branch}" == "-" ]]; then
        printf '  row %s: ohos lane without an OpenHarmony branch\n' "${id}"; bad_rows=$((bad_rows+1))
    fi
    if [[ "${kind}" == "upstream" && "${branch}" != "-" ]]; then
        printf '  row %s: upstream lane claims branch "%s"\n' "${id}" "${branch}"; bad_rows=$((bad_rows+1))
    fi
done < "${OKCP_LANES_FILE}"
assert_eq "every matrix row is well formed" "0" "${bad_rows}"

# Lane ids must be unique — a duplicate would silently shadow an earlier row.
dupes=$(awk -F'\t' '/^#/ {next} NF>=8 {print $1}' "${OKCP_LANES_FILE}" | sort | uniq -d)
assert_eq "lane ids are unique" "" "${dupes}"

#==============================================================================
section "lane resolution"
#==============================================================================

assert_eq "primary resolves to the 6.6.101 lane" "ohos-7.0-6.6" "$(lane_resolve primary)"
assert_eq "latest resolves to the same"           "ohos-7.0-6.6" "$(lane_resolve latest)"
assert_eq "exact id"                              "ohos-7.0-5.10" "$(lane_resolve ohos-7.0-5.10)"
assert_eq "by OpenHarmony branch"                 "ohos-7.0-6.6"  "$(lane_resolve ohos@OpenHarmony-7.0-Release)"
assert_eq "by version@branch"                     "ohos-7.0-6.6"  "$(lane_resolve 6.6.101@OpenHarmony-7.0-Release)"
assert_eq "by kernel version"                     "ohos-7.0-5.10" "$(lane_resolve 5.10.210)"
assert_true "an unknown selector is rejected"     bash -c "source '${ROOT}/scripts/lib/matrix.sh' >/dev/null 2>&1; lane_resolve no-such-lane >/dev/null 2>&1; [[ \$? -ne 0 ]]"

# The headline promise of the project: the default lane is OpenHarmony 7.0
# carrying Linux 6.6.101.  Assert both halves independently so a failure says
# which one broke.
_primary=$(lane_resolve primary)
assert_eq "the primary lane targets the 7.0 release branch" \
          "OpenHarmony-7.0-Release" "$(lane_ohos_branch "${_primary}")"
assert_eq "the primary lane carries Linux 6.6.101" \
          "6.6.101" "$(lane_kver "${_primary}")"
assert_eq "the primary lane builds an arm64 kernel" \
          "arm64" "$(config_arch "${_primary}")"
assert_eq "the primary lane draws from the OpenHarmony kernel repo" \
          "kernel_linux_6.6" "$(lane_repo "${_primary}")"

#==============================================================================
section "URL construction"
#==============================================================================

assert_eq "OHOS lane URL"  "https://gitcode.com/openharmony/kernel_linux_6.6.git" "$(lane_url ohos-7.0-6.6)"
assert_eq "upstream lane URL" "https://github.com/ophub/linux-6.18.y.git"         "$(lane_url upstream-6.18.y)"
assert_true "no URL is double-schemed" bash -c "[[ '$(lane_url ohos-7.0-6.6)' != *'https://https'* ]]"

#==============================================================================
section "patch selection"
#==============================================================================

# ohos lanes key off the upstream series token; upstream lanes use the repo name.
assert_eq "6.6.101 selects linux-6.6.y"  "linux-6.6.y"  "$(patch_series_for_lane ohos-7.0-6.6)"
assert_eq "5.10.210 selects linux-5.10.y" "linux-5.10.y" "$(patch_series_for_lane ohos-7.0-5.10)"
assert_eq "upstream lane uses its repo name" "linux-6.18.y" "$(patch_series_for_lane upstream-6.18.y)"

# Common patches come first, then the series ones, each in name order.
tmp=$(make_tmpdir)
mkdir -p "${tmp}/common-kernel-patches" "${tmp}/linux-6.6.y" "${tmp}/deprecated-patches"
: > "${tmp}/common-kernel-patches/200-second.patch"
: > "${tmp}/common-kernel-patches/100-first.patch"
: > "${tmp}/linux-6.6.y/300-series.patch"
: > "${tmp}/deprecated-patches/999-must-be-ignored.patch"
order=$(collect_patches ohos-7.0-6.6 "${tmp}" | xargs -n1 basename | tr '\n' ' ')
assert_eq "patches apply common-then-series, in order, ignoring other dirs" \
          "100-first.patch 200-second.patch 300-series.patch " "${order}"
rm -rf "${tmp}"

#==============================================================================
section "config layer selection"
#==============================================================================

assert_eq "arm64 for the 6.6 lane"  "arm64" "$(config_arch ohos-7.0-6.6)"
assert_eq "arm64 for the 5.10 lane" "arm64" "$(config_arch ohos-7.0-5.10)"
assert_eq "arm for the 4.19 lane"   "arm"   "$(config_arch ohos-4.0b1-4.19)"

# A defconfig is a *fragment* when small, a *complete config* when large or
# carrying the kconfig "generated" banner.  Both forms occur in
# kernel_linux_config and both must be detected correctly.
tmp=$(make_tmpdir)
printf 'CONFIG_A=y\n' > "${tmp}/small.config"
if config_is_full "${tmp}/small.config"; then r=full; else r=fragment; fi
assert_eq  "a small file is a fragment"     "fragment" "${r}"

seq 1 2500 > "${tmp}/big.config"
if config_is_full "${tmp}/big.config"; then r=full; else r=fragment; fi
assert_eq  "a large file is a complete config" "full" "${r}"

printf '#\n# Automatically generated file; DO NOT EDIT.\n# Linux/arm64 6.6.101 Kernel Configuration\n' > "${tmp}/banner.config"
if config_is_full "${tmp}/banner.config"; then r=full; else r=fragment; fi
assert_eq  "the kconfig banner marks a complete config" "full" "${r}"
rm -rf "${tmp}"

#==============================================================================
section "local overlay fragments are wired to the matrix"
#==============================================================================

# The overlay column must name a directory that exists, otherwise a lane
# silently builds with no local deltas.
missing_overlay=0
while IFS=$'\t' read -r id kind repo host branch kver overlay status note; do
    [[ -z "${id}" || "${id}" == \#* ]] && continue
    [[ -d "${ROOT}/configs/lanes/${overlay}" ]] || {
        printf '  lane %s: no directory configs/lanes/%s\n' "${id}" "${overlay}"; missing_overlay=$((missing_overlay+1)); }
done < "${OKCP_LANES_FILE}"
assert_eq "every lane's overlay directory exists" "0" "${missing_overlay}"

#==============================================================================
section "compliance invariants"
#==============================================================================

if [[ -f "${ROOT}/LICENSE" ]]; then
    assert_eq "LICENSE is the verbatim GPL-2.0 text" "b234ee4d69f5fce4486a80fdaf4a4263" \
              "$(md5sum "${ROOT}/LICENSE" | cut -d' ' -f1)"
else
    SKIP=$((SKIP+1)); printf '  skip LICENSE missing\n'
fi

# A derived file must never claim -or-later: GPL-2.0 section 4 forbids
# sublicensing, so "or later" would be an unauthorised relaxation.
or_later=$(grep -rlE 'SPDX-License-Identifier:.*or-later' "${ROOT}/scripts" "${ROOT}/ohos-kb" 2>/dev/null | tr '\n' ' ')
assert_eq "no source file claims -or-later" "" "${or_later}"

# Every library and the CLI must carry an SPDX identifier.
missing_spdx=""
for f in "${ROOT}"/scripts/lib/*.sh "${ROOT}/ohos-kb"; do
    grep -q 'SPDX-License-Identifier' "${f}" || missing_spdx+=" $(basename "${f}")"
done
assert_eq "every source file carries an SPDX identifier" "" "${missing_spdx}"

#==============================================================================
section "CLI"
#==============================================================================

cli_out=$("${ROOT}/ohos-kb" list-lanes 2>&1)
assert_contains "list-lanes renders the primary lane" "${cli_out}" "ohos-7.0-6.6"
assert_contains "list-lanes shows the 6.6.101 version" "${cli_out}" "6.6.101"
assert_contains "list-lanes reports a total"           "${cli_out}" "Total:"

assert_contains "show resolves the branch"  "$("${ROOT}/ohos-kb" show primary 2>&1)" "OpenHarmony-7.0-Release"
assert_contains "show resolves the version"  "$("${ROOT}/ohos-kb" show primary 2>&1)" "6.6.101"
assert_contains "doctor reports the lane count" "$("${ROOT}/ohos-kb" doctor 2>&1)" "lanes defined"
assert_contains "version prints"              "$("${ROOT}/ohos-kb" version 2>&1)" "ohos-kb"

# Unknown commands and options must fail loudly, not silently do nothing.
if "${ROOT}/ohos-kb" no-such-command >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); FAILURES+=("unknown command should exit non-zero")
    printf '  \033[0;31mFAIL\033[0m unknown command should exit non-zero\n'
else
    PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   unknown command exits non-zero\n'
fi
if "${ROOT}/ohos-kb" show primary --no-such-flag >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); FAILURES+=("unknown option should exit non-zero")
    printf '  \033[0;31mFAIL\033[0m unknown option should exit non-zero\n'
else
    PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   unknown option exits non-zero\n'
fi

#==============================================================================
section "CI workflows"
#==============================================================================

# Structural validation.  CI has PyYAML and does a real parse; locally this
# degrades to the checks a hand-rolled validator can get right.
if python3 "${HERE}/yaml_check.py" > "${TMPDIR:-/tmp}/okcp-yaml.$$" 2>&1; then
    PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   workflows are structurally valid\n'
else
    FAIL=$((FAIL+1)); FAILURES+=("workflow validation failed")
    printf '  \033[0;31mFAIL\033[0m workflows:\n'
    sed 's/^/        /' "${TMPDIR:-/tmp}/okcp-yaml.$$"
fi
rm -f "${TMPDIR:-/tmp}/okcp-yaml.$$"

# No workflow may reference a CLI that does not exist.  A workflow built
# against a deleted entry point is the failure mode this project has already
# hit once.
stale=$(grep -rn "scripts/ohos-kb" "${ROOT}/.github/workflows" 2>/dev/null | wc -l)
assert_eq "no workflow references a non-existent CLI" "0" "${stale}"

# Every workflow that builds must drive ./ohos-kb rather than reimplementing
# the pipeline, so the gate and the local CLI cannot drift apart.
for w in build-kernel kernel-config-check release; do
    f="${ROOT}/.github/workflows/${w}.yml"
    if [[ -f "${f}" ]]; then
        if grep -q "ohos-kb" "${f}"; then
            PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s.yml drives ./ohos-kb\n' "${w}"
        else
            FAIL=$((FAIL+1)); FAILURES+=("${w}.yml does not call ./ohos-kb")
            printf '  \033[0;31mFAIL\033[0m %s.yml does not call ./ohos-kb\n' "${w}"
        fi
    fi
done

#==============================================================================
section "documentation"
#==============================================================================

# The README claims specific numbers; the docs must not rot away from them.
for f in README.md README.cn.md; do
    if [[ -f "${ROOT}/${f}" ]] && grep -q "6.6.101" "${ROOT}/${f}"; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s states the target version\n' "${f}"
    else
        FAIL=$((FAIL+1)); FAILURES+=("${f} does not state 6.6.101")
        printf '  \033[0;31mFAIL\033[0m %s does not state 6.6.101\n' "${f}"
    fi
done

for f in docs/VERSION-MATRIX.md docs/PORTING-NOTES.md docs/BOOT-IMAGE.md docs/COMPLIANCE.md configs/README.md; do
    if [[ -s "${ROOT}/${f}" ]]; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   %s exists\n' "${f}"
    else
        FAIL=$((FAIL+1)); FAILURES+=("${f} is missing")
        printf '  \033[0;31mFAIL\033[0m %s is missing\n' "${f}"
    fi
done

#==============================================================================
section "regressions"
#==============================================================================

# An environment variable that is *set but empty* breaks git outright:
#   fatal: unable to access '...': Problem with the SSL CA cert
# This shipped as a CI failure: a workflow interpolated ${{ vars.GIT_SSL_CAINFO }}
# into `env:`, and an unconfigured GitHub Actions variable yields "" rather than
# leaving the variable absent.  Two guards: no workflow may declare it at the
# env level, and git_do must ignore an empty value.
bad_env=$(grep -rn "^ *GIT_SSL_CAINFO:" "${ROOT}/.github/workflows" 2>/dev/null | wc -l)
assert_eq "no workflow sets GIT_SSL_CAINFO in env (empty breaks git)" "0" "${bad_env}"

if GIT_SSL_CAINFO="" bash -c "source '${ROOT}/scripts/lib/common.sh' >/dev/null 2>&1; git_do --version" >/dev/null 2>&1; then
    PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   git_do tolerates an empty GIT_SSL_CAINFO\n'
else
    FAIL=$((FAIL+1)); FAILURES+=("git_do fails when GIT_SSL_CAINFO is empty")
    printf '  \033[0;31mFAIL\033[0m git_do fails when GIT_SSL_CAINFO is empty\n'
fi

# The same class of bug: a workflow must never build a kernel by trusting an
# artefact label rather than the lane.  The release workflow cross-checks the
# tag against the resolved kernel version.
if [[ -f "${ROOT}/.github/workflows/release.yml" ]]; then
    if grep -q "kver" "${ROOT}/.github/workflows/release.yml" && \
       grep -q 'does not start with the lane' "${ROOT}/.github/workflows/release.yml"; then
        PASS=$((PASS+1)); printf '  \033[0;32mok\033[0m   release cross-checks tag against the lane version\n'
    else
        FAIL=$((FAIL+1)); FAILURES+=("release.yml does not cross-check the tag against the lane version")
        printf '  \033[0;31mFAIL\033[0m release.yml does not cross-check the tag\n'
    fi
fi

#==============================================================================
printf '\n\033[1m────────────────────────────────────────\033[0m\n'
printf 'passed %d   failed %d   skipped %d\n' "${PASS}" "${FAIL}" "${SKIP}"
if [[ ${FAIL} -gt 0 ]]; then
    printf '\nfailures:\n'
    for f in "${FAILURES[@]}"; do printf '  - %s\n' "${f}"; done
    exit 1
fi
printf '\033[0;32mall good\033[0m\n'
