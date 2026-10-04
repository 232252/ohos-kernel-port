#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/patch.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Patch application, following ophub's two-tier layout:
#   <patch_root>/common-kernel-patches/   applied to every lane, in name order
#   <patch_root>/linux-<series>.y/        applied only to a matching series
# Any other directory name is ignored (this is how ophub parks
# `deprecated-patches`, and we keep the same contract so existing patch
# collections drop in unchanged).
#=======================================================================

[[ -n "${_OKCP_PATCH_SH:-}" ]] && return 0
_OKCP_PATCH_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"

OKCP_PATCH_ROOT="${OKCP_ROOT}/patches"

# The series token used to pick a dedicated patch directory.
# OHOS lanes use the plain upstream series (linux-6.6.y); ophub BSP lanes keep
# their own token (linux-6.1.y-rockchip).
patch_series_for_lane() {
    local lane=$1 repo kver
    if [[ "$(lane_source_kind "${lane}")" == "upstream" ]]; then
        lane_repo "${lane}"; return 0          # linux-6.18.y, linux-5.10.y-rk35xx, ...
    fi
    repo=$(lane_repo "${lane}")
    printf 'linux-%s.y\n' "$(kernel_series "$(lane_kver "${lane}")")"
}

# Collect the patch files that apply to <lane>, in the order they must be run.
# Prints one path per line.
collect_patches() {
    local lane=$1 root=${2:-${OKCP_PATCH_ROOT}} series common_dir series_dir
    series=$(patch_series_for_lane "${lane}")
    common_dir="${root}/common-kernel-patches"
    series_dir="${root}/${series}"

    [[ -d "${common_dir}" ]] && find "${common_dir}" -maxdepth 1 -type f -name '*.patch' | sort
    if [[ -d "${series_dir}" ]]; then
        find "${series_dir}" -maxdepth 1 -type f -name '*.patch' | sort
    else
        log_debug "no dedicated patch dir for series '${series}' (${series_dir})"
    fi
}

# apply_patches <lane> <srcdir> [patch_root]
#
# Patches are applied with `git am` so that a clean tree stays clean and a
# failed patch is a hard error rather than a silently half-patched kernel.
apply_patches() {
    local lane=$1 srcdir=$2 root=${3:-${OKCP_PATCH_ROOT}}
    local -a patches=()
    local p applied=0 failed=0

    mapfile -t patches < <(collect_patches "${lane}" "${root}")
    if [[ ${#patches[@]} -eq 0 ]]; then
        log_info "no patches to apply for lane '${lane}' (patch root: ${root})"
        return 0
    fi

    log_step "applying ${#patches[@]} patch(es) to ${lane}"
    git_do -C "${srcdir}" rev-parse --git-dir >/dev/null 2>&1 || \
        die "patch application requires a git checkout; ${srcdir} is not one"

    # `git am` creates a commit, and a commit needs a committer identity.  A
    # fresh CI runner has none: actions/checkout sets no user.name/user.email,
    # so git fails with "Committer identity unknown" — which reads like a patch
    # conflict and is not one.  Supply a fallback rather than requiring every
    # environment to be configured, and never override an identity already set.
    local -a ident=()
    if ! git_do -C "${srcdir}" config --get user.email >/dev/null 2>&1; then
        ident=(-c "user.name=ohos-kernel-port" -c "user.email=ohos-kernel-port@localhost")
        log_debug "no git identity in the tree; using the project fallback"
    fi

    for p in "${patches[@]}"; do
        local rel=${p#"${srcdir}/"} out
        # Capture the output rather than redirecting it to a file: a CI
        # runner's scratch tree is unreachable afterwards, so a failure has to
        # print its own diagnosis instead of pointing at a file nobody can open.
        if out=$(git_do -C "${srcdir}" "${ident[@]}" am --3way --keep-non-patch "${p}" 2>&1); then
            log_debug "applied: ${rel}"
            applied=$((applied+1))
        else
            failed=$((failed+1))
            log_error "patch FAILED: ${rel}"
            log_error "--- git am output ---"
            printf '%s\n' "${out}" | sed 's/^/    /' >&2
            log_error "------------------------"
            log_error "  recover: git -C ${srcdir} am --abort"
            log_error "  retry:   git -C ${srcdir} am --3way ${p}"
            printf '%s\n' "${out}" > "${srcdir}/.okcp-patch.log" 2>/dev/null || true
            break
        fi
    done

    if [[ ${failed} -gt 0 ]]; then
        return 1
    fi
    log_ok "applied ${applied} patch(es) to ${lane}"
}

# Reverse-apply is used by `ohos-kb clean --revert-patches`.
revert_patches() {
    local srcdir=$1
    git_do -C "${srcdir}" am --abort >/dev/null 2>&1 || true
    local n
    n=$(git_do -C "${srcdir}" log --oneline 2>/dev/null | grep -c '^\s*\[PATCH\]' || true)
    log_info "nothing to revert beyond aborted am session (${n} patch commits in tree)"
}

# Sanity check used by CI before a full build: can every patch be applied?
check_patches() {
    local lane=$1 srcdir=$2 root=${3:-${OKCP_PATCH_ROOT}}
    local -a patches=()
    mapfile -t patches < <(collect_patches "${lane}" "${root}")
    printf '%s\n' "${#patches[@]}"
    [[ ${#patches[@]} -gt 0 ]] && printf '%s\n' "${patches[@]}"
}
