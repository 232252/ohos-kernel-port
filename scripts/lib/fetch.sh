#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/fetch.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Kernel source acquisition.
#
# The single behavioural change versus the ophub pipeline lives here: ophub
# resolves `unifreq/linux-<series>.y` and `ophub/linux-<series>.y`, whereas this
# project resolves the OpenHarmony kernel repositories on gitcode.com and checks
# out the matching `OpenHarmony-<x.y>-Release` branch.  Everything downstream
# (patches, config, build, package) is unchanged in shape.
#=======================================================================

[[ -n "${_OKCP_FETCH_SH:-}" ]] && return 0
_OKCP_FETCH_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"

# Cache/fetch tuning knobs (all overridable from the environment).
OKCP_WORKDIR="${OKCP_WORKDIR:-${OKCP_ROOT}/build}"
OKCP_JOBS="${OKCP_JOBS:-$(nproc 2>/dev/null || echo 4)}"
OKCP_FETCH_DEPTH="${OKCP_FETCH_DEPTH:-1}"

# Print the ordered mirror list for a lane, most authoritative first.
# OpenHarmony kernel repos live on gitcode.com; gitee carries an older subset.
# We try mirrors in order so a single mirror outage does not fail the build.
ohos_mirrors_for() {
    local lane=$1 repo host
    lane_exists "${lane}" || die "unknown lane '${lane}' (try: ohos-kb list-lanes)"
    repo=$(lane_repo "${lane}")
    host=$(lane_host "${lane}")
    host=${host#https://}; host=${host#http://}; host=${host%/}

    printf 'https://%s/%s.git\n' "${host}" "${repo}"
    # gitee mirror only exists for a few of the older branches, but it is a
    # useful fallback when gitcode is slow.  Only offered for OHOS lanes.
    # (source_host may include the org path, e.g. "gitcode.com/openharmony")
    if [[ "$(lane_source_kind "${lane}")" == "ohos" && "${host}" == gitcode.com* ]]; then
        printf 'https://gitee.com/openharmony/%s.git\n' "${repo}"
    fi
}

# _try_clone <url> <branch|-> <dest>
_try_clone() {
    local url=$1 branch=$2 dest=$3
    local -a args=(clone --depth="${OKCP_FETCH_DEPTH}" --single-branch --no-tags)
    [[ "${branch}" != "-" ]] && args+=(--branch "${branch}")
    args+=("${url}" "${dest}")
    git_do "${args[@]}"
}

# fetch_kernel_source <lane> [dest]
#
# Clones the lane's kernel tree into <dest> (default ${OKCP_WORKDIR}/src/<lane>).
# Existing, valid trees are reused unless OKCP_FORCE_FETCH=1.
fetch_kernel_source() {
    local lane=$1 dest=${2:-}
    [[ -n "${dest}" ]] || dest="${OKCP_WORKDIR}/src/${lane}"

    require_file "${OKCP_LANES_FILE}"
    lane_exists "${lane}" || die "unknown lane '${lane}' (try: ohos-kb list-lanes)"

    local url branch repo mirror dest_parent
    url=$(lane_url "${lane}")
    branch=$(lane_ohos_branch "${lane}")
    repo=$(lane_repo "${lane}")
    dest_parent=$(dirname -- "${dest}")
    mkdir -p "${dest_parent}"

    # --- reuse an existing tree ------------------------------------------
    if [[ -d "${dest}/.git" ]]; then
        if [[ -n "${OKCP_FORCE_FETCH:-}" ]]; then
            log_step "refreshing existing tree (OKCP_FORCE_FETCH): ${dest}"
        else
            log_step "reusing existing tree: ${dest}"
            printf '%s\n' "${dest}"
            return 0
        fi
    fi

    # --- clone, walking the mirror list ---------------------------------
    log_step "fetching ${lane}"
    log_info "repo   : $(lane_repo "${lane}")"
    log_info "branch : ${branch}"
    log_info "url    : ${url}"

    local ok=0
    while read -r mirror; do
        [[ -n "${mirror}" ]] || continue
        log_info "trying  : ${mirror}"
        rm -rf "${dest}"
        # ophub retries a clone 10 times with a 60s pause; gitcode can rate
        # limit hard under CI, so keep a similarly persistent default here.
        if retry "${OKCP_FETCH_ATTEMPTS:-10}" "${OKCP_FETCH_BACKOFF:-30}" \
                _try_clone "${mirror}" "${branch}" "${dest}"; then
            ok=1; break
        fi
        log_warn "mirror failed, falling through to next: ${mirror}"
    done < <(ohos_mirrors_for "${lane}")

    [[ "${ok}" == "1" ]] || die "all mirrors failed for lane '${lane}'
  Checked:
$(ohos_mirrors_for "${lane}" | sed 's/^/    /')
  If you are behind a TLS-intercepting proxy, export
  GIT_SSL_CAINFO=/path/to/proxy-ca.crt and retry."

    [[ -f "${dest}/Makefile" ]] || die "clone finished but ${dest}/Makefile is missing (unexpected source layout)"

    # --- verify what we actually got ------------------------------------
    local actual declared head
    actual=$(lane_verify_kver "${lane}" "${dest}")
    declared=$(lane_kver "${lane}")
    head=$(git_do -C "${dest}" rev-parse --short=12 HEAD 2>/dev/null || echo '?')

    log_ok "fetched ${repo}@${branch} = Linux ${actual} (commit ${head})"
    [[ "${actual}" == "${declared}" ]] || \
        log_warn "matrix records ${declared} for this lane but the branch now carries ${actual}"

    # Record provenance next to the tree so packaging can stamp it in.
    {
        printf 'lane=%s\n'     "${lane}"
        printf 'repo=%s\n'     "${repo}"
        printf 'branch=%s\n'   "${branch}"
        printf 'commit=%s\n'   "$(git_do -C "${dest}" rev-parse HEAD 2>/dev/null || echo unknown)"
        printf 'kver=%s\n'     "${actual}"
        printf 'declared_kver=%s\n' "${declared}"
        printf 'source_url=%s\n' "${url}"
        printf 'fetched_at=%s\n'  "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "${dest}/.okcp-provenance"

    printf '%s\n' "${dest}"
}

# Resolve a pinned commit for a lane, if the matrix ever grows one.
lane_pinned_commit() {
    local lane=$1
    # Reserved for a future `commit` column in the matrix; today every lane
    # tracks the tip of its OpenHarmony branch on purpose (that is what
    # OpenHarmony itself ships).
    printf '\n'
}
