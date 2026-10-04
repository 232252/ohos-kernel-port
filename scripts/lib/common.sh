#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/common.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
#
# Derived from the ophub/kernel build system
#   Copyright (C) 2021 https://github.com/unifreq/openwrt_packit
#   Copyright (C) 2021 https://github.com/ophub/kernel
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# SPDX-License-Identifier: GPL-2.0-only
#=======================================================================
#
# Shared helpers: logging, error handling, network retry, tool discovery.
# Sourced by every other lib; never executed directly.

[[ -n "${_OKCP_COMMON_SH:-}" ]] && return 0
_OKCP_COMMON_SH=1

#------------------------------------------------------------------ logging
if [[ -t 1 && "${NO_COLOR:-}" == "" && "${TERM:-dumb}" != "dumb" ]]; then
    _C_RST=$'\033[0m'; _C_R=$'\033[0;31m'; _C_G=$'\033[0;32m'
    _C_Y=$'\033[0;33m';  _C_B=$'\033[0;34m'; _C_C=$'\033[0;36m'
    _C_D=$'\033[0;90m'; _C_BOLD=$'\033[1m'
else
    _C_RST=''; _C_R=''; _C_G=''; _C_Y=''; _C_B=''; _C_C=''; _C_D=''; _C_BOLD=''
fi

OKCP_TAG='ohos-kb'

log_info()  { printf '%s[%s]%s %s\n'   "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "$*" >&2; }
log_ok()    { printf '%s[%s]%s %s✔%s %s\n' "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "${_C_G}" "${_C_RST}" "$*" >&2; }
log_warn()  { printf '%s[%s]%s %s!%s %s\n' "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "${_C_Y}" "${_C_RST}" "$*" >&2; }
log_error() { printf '%s[%s]%s %s✘%s %s\n' "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "${_C_R}" "${_C_RST}" "$*" >&2; }
log_step()  { printf '%s[%s]%s %s▸%s %s\n' "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "${_C_C}" "${_C_RST}" "$*" >&2; }
log_debug() { [[ -n "${OKCP_DEBUG:-}" ]] || return 0
              printf '%s[%s]%s %s·%s %s\n' "${_C_B}" "${OKCP_TAG}" "${_C_RST}" "${_C_D}" "${_C_RST}" "$*" >&2; }

die() { log_error "$*"; exit 1; }

#------------------------------------------------------------- repo layout
# OKCP_ROOT is the repository root; resolved from this file's location so the
# CLI works from any cwd and from a git checkout without installation.
_okcp_resolve_root() {
    local src=${BASH_SOURCE[1]} dir
    dir=$(cd -- "$(dirname -- "${src}")" && pwd)
    while [[ -n "${dir}" && "${dir}" != "/" ]]; do
        if [[ -f "${dir}/data/ohos-kernel-lanes.tsv" ]]; then
            printf '%s\n' "${dir}"; return 0
        fi
        dir=$(dirname -- "${dir}")
    done
    return 1
}
OKCP_ROOT=$(_okcp_resolve_root "${BASH_SOURCE[0]}") \
    || die "cannot locate repository root (data/ohos-kernel-lanes.tsv not found)"
export OKCP_ROOT

OKCP_LANES_FILE="${OKCP_ROOT}/data/ohos-kernel-lanes.tsv"

#----------------------------------------------------------------- helpers
have() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    local missing=()
    for c in "$@"; do have "${c}" || missing+=("${c}"); done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    die "missing required tool(s): ${missing[*]}
  Debian/Ubuntu:  sudo apt-get install -y ${missing[*]}"
}

require_file() { [[ -f "$1" ]] || die "required file not found: $1"; }

# Human readable elapsed time.
fmt_duration() {
    local s=$1
    (( s < 60 ))    && printf '%ss'    "${s}" && return 0
    (( s < 3600 ))  && printf '%sm%02ds' $((s/60)) $((s%60)) && return 0
    printf '%dh%02dm%02ds' $((s/3600)) $(( (s%3600)/60 )) $((s%60))
}

# Retry a command N times.  Network operations in CI are flaky; this keeps the
# build honest instead of pretending a transient TLS error is a real failure.
#   retry <attempts> <sleep_seconds> <cmd...>
retry() {
    local attempts=$1 sleep_s=$2; shift 2
    local n=1 rc=0
    while :; do
        if "$@"; then return 0; fi
        rc=$?
        if (( n >= attempts )); then
            log_error "command failed after ${n} attempt(s) (exit ${rc}): $*"
            return "${rc}"
        fi
        log_warn "attempt ${n}/${attempts} failed (exit ${rc}), retrying in ${sleep_s}s: $*"
        sleep "${sleep_s}"
        n=$((n + 1))
    done
}

# Sandboxed HTTP GET to stdout, with retries.
http_get() {
    local url=$1 out=${2:-}
    if [[ -n "${out}" ]]; then
        retry 4 5 curl -fsSL --max-time "${OKCP_HTTP_TIMEOUT:-120}" -o "${out}" "${url}"
    else
        retry 4 5 curl -fsSL --max-time "${OKCP_HTTP_TIMEOUT:-120}" "${url}"
    fi
}

# git may need an explicit CA bundle when running behind a TLS-intercepting
# proxy (corporate egress, some CI sandboxes).  Honour it if the caller set one.
git_env() {
    if [[ -n "${GIT_SSL_CAINFO:-}" ]]; then
        printf '%s\n' GIT_SSL_CAINFO="${GIT_SSL_CAINFO}"
    fi
}

# Run git honouring GIT_SSL_CAINFO without leaking it into every call site.
#
# The -n test is load-bearing.  An environment variable that is *set but
# empty* is worse than one that is unset: git reports
#   fatal: unable to access '...': Problem with the SSL CA cert (path? access rights?)
# and every clone fails.  This bites when a CI workflow interpolates an
# unconfigured `${{ vars.SOMETHING }}` into `env:`, which yields an empty
# string rather than leaving the variable absent.
git_do() {
    if [[ -n "${GIT_SSL_CAINFO:-}" ]]; then
        git -c http.sslCAInfo="${GIT_SSL_CAINFO}" "$@"
    else
        git "$@"
    fi
}

# Compare dotted version strings: 0 if equal, -1 if a<b, 1 if a>b
version_cmp() {
    local a=$1 b=$2
    if [[ "${a}" == "${b}" ]]; then printf '0\n'; return 0; fi
    local lo hi
    lo=$(printf '%s\n%s\n' "${a}" "${b}" | sort -V | head -1)
    hi=$(printf '%s\n%s\n' "${a}" "${b}" | sort -V | tail -1)
    [[ "${lo}" == "${a}" ]] && printf '%s\n' '-1' || printf '%s\n' '1'
}

# Best-effort: is $1 at least $2 ?
version_ge() { [[ "$(version_cmp "$1" "$2")" != "-1" ]]; }

# True when stdout is a tty and colour is not disabled.
can_color() { [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; }

# Portable mktemp that works on both GNU and BSD userlands.
make_tmpdir() {
    mktemp -d "${TMPDIR:-/tmp}/ohos-kb.XXXXXXXX"
}

# Convert a possibly-relative path to an absolute one without requiring the
# target to exist.
abspath() {
    local p=$1
    [[ "${p}" == /* ]] || p="${PWD}/${p}"
    printf '%s\n' "${p}"
}
