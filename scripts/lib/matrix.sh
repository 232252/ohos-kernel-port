#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/matrix.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Lane matrix resolution.  A "lane" is one buildable combination of
# kernel source + OpenHarmony release branch.  The authoritative data lives
# in data/ohos-kernel-lanes.tsv; this file only knows how to read it.
#=======================================================================

[[ -n "${_OKCP_MATRIX_SH:-}" ]] && return 0
_OKCP_MATRIX_SH=1

# Shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

OKCP_MATRIX_CACHE=""
OKCP_MATRIX_CACHE_KEY=""

# _lane_row <lane_id> -> prints the raw TSV row (8 tab separated fields)
_lane_row() {
    local id=$1
    [[ -n "${id}" ]] || return 1
    awk -F'\t' -v id="${id}" '
        /^#/ { next }
        NF < 8  { next }
        $1 == id { print; found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "${OKCP_LANES_FILE}"
}

# Public accessors -------------------------------------------------------
lane_field() {
    local id=$1 field=$2 row
    row=$(_lane_row "${id}") || { log_error "unknown lane: ${id} (try: ohos-kb list-lanes)"; return 1; }
    printf '%s\n' "${row}" | cut -f"${field}"
}

lane_exists()      { _lane_row "$1" >/dev/null 2>&1; }
lane_source_kind() { lane_field "$1" 2; }
lane_repo()        { lane_field "$1" 3; }
lane_host()        { lane_field "$1" 4; }
lane_ohos_branch() { lane_field "$1" 5; }
lane_kver()        { lane_field "$1" 6; }
lane_overlay()     { lane_field "$1" 7; }
lane_status()      { lane_field "$1" 8; }
lane_note()        { lane_field "$1" 9; }

lane_url() {
    local id=$1 host
    # source_host is stored as a full URL ("https://host"); tolerate a bare
    # host too so the matrix stays easy to hand-edit.
    host=$(lane_host "${id}")
    host=${host#https://}; host=${host#http://}; host=${host%/}
    printf 'https://%s/%s.git\n' "${host}" "$(lane_repo "${id}")"
}

# The major.minor series token for a lane's kernel version.
#   6.6.101 -> 6.6      5.10.210 -> 5.10      4.19.155 -> 4.19
#
# Both the patch directory name (linux-6.6.y) and the OpenHarmony config
# directory (kernel_linux_config/linux-6.6/) are keyed on this, so it is
# derived in exactly one place.
#
# Note the subtlety: ${kver%%.*} strips the LONGEST matching suffix and would
# turn "6.6.101" into "6", which makes every config and patch lookup miss and
# fall back silently.  Strip only the patchlevel instead.
kernel_series() {
    local kver=$1 series
    series=$(printf '%s\n' "${kver}" | cut -d. -f1,2)
    # A single-component version has no series; fall back to itself.
    [[ "${series}" == *.* ]] || series="${kver%%.*}"
    printf '%s\n' "${series}"
}

# All lane ids, in matrix order.
lane_ids() {
    awk -F'\t' '/^#/ { next } NF >= 8 { print $1 }' "${OKCP_LANES_FILE}"
}

lane_ids_by_status() {
    local want=${1:-}
    awk -F'\t' -v want="${want}" '
        /^#/ { next } NF < 8 { next }
        want == "" || $8 == want { print $1 }
    ' "${OKCP_LANES_FILE}"
}

# Every distinct kernel version in the matrix, newest first.
lane_kvers() {
    awk -F'\t' '/^#/ { next } NF >= 8 { print $6 }' "${OKCP_LANES_FILE}" | sort -uVr
}

# Resolve a user-supplied selector to a concrete lane id.
# Accepts (in order of precedence):
#   * an exact lane id                     e.g. ohos-7.0-6.6
#   * "ohos@<branch>"                      e.g. ohos@OpenHarmony-7.0-Release
#   * "<version>@<branch>"                 e.g. 6.6.101@OpenHarmony-7.0-Release
#   * "<branch>"                           e.g. OpenHarmony-7.0-Release
#   * "latest" / "primary"                 highest-priority primary lane
#   * "<kver>"  (shortest-prefix match)    e.g. 6.6.101
lane_resolve() {
    local sel=${1:-}; [[ -n "${sel}" ]] || sel='primary'
    local id

    if lane_exists "${sel}"; then printf '%s\n' "${sel}"; return 0; fi

    case "${sel}" in
        latest|primary)
            id=$(lane_ids_by_status primary | head -1)
            [[ -n "${id}" ]] || die "no lane with status=primary in ${OKCP_LANES_FILE}"
            printf '%s\n' "${id}"; return 0
            ;;
    esac

    # ohos@BRANCH
    if [[ "${sel}" == *@* ]]; then
        local kver=${sel%%@*} branch=${sel##*@}
        id=$(awk -F'\t' -v k="${kver}" -v b="${branch}" '
            /^#/ { next } NF < 8 { next }
            ($6 == k || ($2 == "ohos" && $1 ~ k)) && $5 == b { print $1; exit }
        ' "${OKCP_LANES_FILE}")
        [[ -n "${id}" ]] || die "no lane for selector '${sel}' (kver='${kver}' branch='${branch}')"
        printf '%s\n' "${id}"; return 0
    fi

    # exact ohos branch
    id=$(awk -F'\t' -v b="${sel}" '
        /^#/ { next } NF < 8 { next }
        $5 == b { print $1; exit }
    ' "${OKCP_LANES_FILE}")
    [[ -n "${id}" ]] && { printf '%s\n' "${id}"; return 0; }

    # kernel version (prefix match, longest version first)
    id=$(awk -F'\t' -v k="${sel}" '
        /^#/ { next } NF < 8 { next }
        index($6, k) == 1 { print $1; exit }
    ' "${OKCP_LANES_FILE}")
    [[ -n "${id}" ]] && { printf '%s\n' "${id}"; return 0; }

    die "cannot resolve lane selector '${sel}'
  Run 'ohos-kb list-lanes' to see the full matrix."
}

# Cross-check a lane's declared kver against the tree actually fetched.
# Mismatch means the remote branch moved (or the matrix is stale) and we must
# not silently build something mislabelled.
lane_verify_kver() {
    local lane=$1 srcdir=$2 declared actual
    declared=$(lane_kver "${lane}")
    require_file "${srcdir}/Makefile"
    actual=$(awk '
        /^VERSION *=/     { v=$3 }
        /^PATCHLEVEL *=/  { p=$3 }
        /^SUBLEVEL *=/    { s=$3 }
        END { if (v != "" && p != "" && s != "") printf "%s.%s.%s\n", v, p, s }
    ' "${srcdir}/Makefile")
    [[ -n "${actual}" ]] || die "cannot parse kernel version from ${srcdir}/Makefile"

    if [[ "${declared}" != "${actual}" ]]; then
        # upstream-* lanes declare a rolling ".y" series on purpose.
        if [[ "$(lane_source_kind "${lane}")" == "upstream" ]]; then
            if [[ "${declared}" == "${actual}" || "${declared%.y}" == "${actual%.*}" ]]; then
                log_debug "lane ${lane}: series ${declared} resolved to ${actual} (expected for upstream lane)"
                printf '%s\n' "${actual}"; return 0
            fi
        fi
        log_warn "version drift on lane '${lane}':"
        log_warn "  matrix says : ${declared}"
        log_warn "  source says : ${actual}"
        log_warn "  the upstream branch moved; update data/ohos-kernel-lanes.tsv"
        printf '%s\n' "${actual}"; return 0
    fi
    printf '%s\n' "${actual}"
}

# Pretty print the matrix.
lane_table() {
    local want=${1:-}
    awk -F'\t' -v want="${want}" '
        BEGIN { printf "%-24s %-9s %-30s %-34s %-11s %-9s %-12s\n",
                "LANE","SOURCE","REPO","OPENHARMONY BRANCH","KVER","OVERLAY","STATUS" }
        /^#/ { next } NF < 8 { next }
        want != "" && $8 != want { next }
        { printf "%-24s %-9s %-30s %-34s %-11s %-9s %-12s\n", $1, $2, $3, $5, $6, $7, $8 }
    ' "${OKCP_LANES_FILE}"
}
