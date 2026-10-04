#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/toolchain.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Cross toolchain acquisition and verification.
#
# Provenance: the GNU Arm Embedded toolchains are republished by ophub/kernel
# in the `toolchain` release of that repository, because OpenWrt/Armbian CI
# needs a pinned, cacheable toolchain and kernel.org tarballs do not provide
# one.  We consume the same artifacts rather than re-hosting them, so the
# download is verified against the digest GitHub reports for the asset.
#
#   Release:  https://github.com/ophub/kernel/releases/tag/toolchain
#   Pinned in data/toolchains.tsv (name + sha256 + size).
#=======================================================================

[[ -n "${_OKCP_TOOLCHAIN_SH:-}" ]] && return 0
_OKCP_TOOLCHAIN_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"

OKCP_TOOLCHAIN_FILE="${OKCP_ROOT}/data/toolchains.tsv"
OKCP_TOOLCHAIN_BASE_URL="${OKCP_TOOLCHAIN_BASE_URL:-https://github.com/ophub/kernel/releases/download/toolchain}"
OKCP_TOOLCHAIN_CACHE="${OKCP_TOOLCHAIN_CACHE:-${OKCP_ROOT}/build/toolchains}"

#--------------------------------------------------------------- table access
_tc_row() {
    local id=$1
    [[ -n "${id}" ]] || return 1
    awk -F'\t' -v id="${id}" '
        /^#/ { next } NF < 10 { next }
        $1 == id { print; found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "${OKCP_TOOLCHAIN_FILE}"
}

tc_field() {
    local id=$1 field=$2 row
    row=$(_tc_row "${id}") || { log_error "unknown toolchain id: ${id} (try: ohos-kb toolchain list)"; return 1; }
    printf '%s\n' "${row}" | cut -f"${field}"
}

tc_ids() { awk -F'\t' '/^#/ { next } NF >= 9 { print $1 }' "${OKCP_TOOLCHAIN_FILE}"; }

tc_table() {
    awk -F'\t' '
        BEGIN { printf "%-20s %-7s %-9s %-10s %-10s %s\n",
                "ID","ARCH","HOST","VERSION","SIZE(MB)","ASSET" }
        /^#/ { next } NF < 10 { next }
        { printf "%-20s %-7s %-9s %-10s %-10.1f %s%s\n", $1, $2, $3, $4, $7/1000000, $5, ($10==1?"  [default]":"") }
    ' "${OKCP_TOOLCHAIN_FILE}"
}

# Decide which toolchain row to use.
#   tc_select <arch> [host_arch]
# - host_arch defaults to `uname -m`.  A native match (target == host) is
# preferred over a cross build when both are marked default, because the
# native tarball is a bit faster and needs no emulation.
tc_select() {
    local arch=${1:-arm64} host=${2:-$(uname -m)} row
    case "${host}" in
        arm64|aarch64) host=aarch64 ;;
        x86_64|amd64)  host=x86_64  ;;
        *)             log_warn "unrecognised host arch '${host}'; falling back to x86_64 cross toolchain"
                       host=x86_64 ;;
    esac

    # 1. exact (arch, host) default
    row=$(awk -F'\t' -v a="${arch}" -v h="${host}" '
        /^#/ { next } NF < 10 { next }
        $2 == a && $3 == h && $10 == 1 { print $1; exit }
    ' "${OKCP_TOOLCHAIN_FILE}")
    # 2. exact (arch, host), any version
    [[ -n "${row}" ]] || row=$(awk -F'\t' -v a="${arch}" -v h="${host}" '
        /^#/ { next } NF < 10 { next }
        $2 == a && $3 == h { print $1; exit }
    ' "${OKCP_TOOLCHAIN_FILE}")
    # 3. any default for this arch
    [[ -n "${row}" ]] || row=$(awk -F'\t' -v a="${arch}" '
        /^#/ { next } NF < 10 { next }
        $2 == a && $10 == 1 { print $1; exit }
    ' "${OKCP_TOOLCHAIN_FILE}")
    # 4. first row for this arch
    [[ -n "${row}" ]] || row=$(awk -F'\t' -v a="${arch}" '
        /^#/ { next } NF < 10 { next }
        $2 == a { print $1; exit }
    ' "${OKCP_TOOLCHAIN_FILE}")

    [[ -n "${row}" ]] || die "no toolchain row for arch '${arch}' in ${OKCP_TOOLCHAIN_FILE}"
    printf '%s\n' "${row}"
}

#-------------------------------------------------------------- sha256 verify
sha256_of() {
    if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
    elif have shasum;   then shasum -a 256 "$1" | cut -d' ' -f1
    else die "neither sha256sum nor shasum is available; cannot verify downloads"
    fi
}

# verify_sha256 <file> <expected>
verify_sha256() {
    local file=$1 want=$2 got
    [[ -f "${file}" ]] || { log_error "cannot verify missing file: ${file}"; return 1; }
    got=$(sha256_of "${file}")
    if [[ "${got}" == "${want}" ]]; then
        log_ok "sha256 OK: $(basename -- "${file}")"
        return 0
    fi
    log_error "sha256 MISMATCH: $(basename -- "${file}")"
    log_error "  expected : ${want}"
    log_error "  actual   : ${got}"
    return 1
}

#------------------------------------------------------------------ download
# fetch_toolchain <toolchain_id> [cache_dir]
#
# Prints the toolchain prefix directory (the one containing bin/<triple>-gcc).
# A verified cache entry is reused; the digest is re-checked on every reuse so
# a corrupted CI cache cannot silently poison a build.
fetch_toolchain() {
    local id=${1:-} cache=${2:-${OKCP_TOOLCHAIN_CACHE}}
    [[ -n "${id}" ]] || die "fetch_toolchain: missing toolchain id"

    local asset sha size triple prefix unpack
    asset=$(tc_field "${id}" 5)
    sha=$(tc_field   "${id}" 6)
    size=$(tc_field  "${id}" 7)
    triple=$(tc_field "${id}" 8)
    prefix="${cache}/${id}"
    unpack="${cache}/.unpack-${id}"

    mkdir -p "${cache}"

    # --- fast path: already unpacked and self-consistent ---------------
    if [[ -x "${prefix}/bin/${triple}-gcc" ]]; then
        if [[ -f "${prefix}/.okcp-sha256" && "$(cat "${prefix}/.okcp-sha256")" == "${sha}" ]]; then
            log_step "toolchain ${id} already unpacked (cache hit): ${prefix}"
            printf '%s\n' "${prefix}"
            return 0
        fi
        log_warn "cached toolchain ${id} is not the pinned build; re-fetching"
        rm -rf "${prefix}"
    fi

    # --- download the tarball ------------------------------------------
    local tarball="${cache}/${asset}"
    if [[ -f "${tarball}" ]]; then
        log_step "toolchain archive already downloaded, verifying: ${asset}"
        if ! verify_sha256 "${tarball}" "${sha}"; then
            log_warn "discarding corrupt archive ${tarball}"
            rm -f "${tarball}"
        fi
    fi

    if [[ ! -f "${tarball}" ]]; then
        log_step "downloading ${asset}"
        log_info "url: ${OKCP_TOOLCHAIN_BASE_URL}/${asset}"
        rm -f "${tarball}"
        # -L follows GitHub's redirect to objects.githubusercontent.com;
        # --retry keeps a transient CDN 5xx from failing a 5-hour build.
        retry 4 10 curl -fL --retry 3 --retry-delay 5 \
            --connect-timeout 30 \
            --max-time "${OKCP_HTTP_TIMEOUT:-1800}" \
            -o "${tarball}" "${OKCP_TOOLCHAIN_BASE_URL}/${asset}" \
            || die "failed to download toolchain archive: ${asset}"

        # A short read that still passes curl's exit code is the classic CI
        # failure mode here, so check the size before trusting the digest.
        local got_size
        got_size=$(wc -c < "${tarball}")
        if [[ "${size}" != "0" && "${got_size}" -lt $(( size * 90 / 100 )) ]]; then
            die "downloaded toolchain is too small: ${got_size} bytes (expected ~${size})
  This is a truncated download. Re-run; the cache entry has been removed."
        fi
        verify_sha256 "${tarball}" "${sha}" \
            || die "refusing to use a toolchain whose digest does not match the pinned value"
    fi

    # --- unpack --------------------------------------------------------
    log_step "unpacking ${asset}"
    rm -rf "${unpack}"
    mkdir -p "${unpack}"
    have xz || die "xz is required to unpack the toolchain (Debian/Ubuntu: apt-get install -y xz-utils)"
    tar -xf "${tarball}" -C "${unpack}"

    # GNU Arm tarballs unpack to a top-level directory named after the
    # version, e.g. arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.
    # Normalise whatever we got into a single predictable prefix.
    local inner
    inner=$(find "${unpack}" -maxdepth 1 -mindepth 1 -type d | head -1)
    [[ -n "${inner}" ]] || die "toolchain archive did not contain a top-level directory"
    if [[ ! -x "${inner}/bin/${triple}-gcc" ]]; then
        log_error "expected ${inner}/bin/${triple}-gcc is missing."
        log_error "Archive layout changed upstream. Re-check data/toolchains.tsv."
        die "toolchain layout mismatch for id '${id}'"
    fi

    rm -rf "${prefix}"
    mv "${inner}" "${prefix}"
    rm -rf "${unpack}"
    printf '%s\n' "${sha}" > "${prefix}/.okcp-sha256"

    # --- smoke test ----------------------------------------------------
    "${prefix}/bin/${triple}-gcc" --version >/dev/null 2>&1 \
        || die "unpacked toolchain ${id} does not execute (wrong host arch? table says host=$(tc_field "${id}" 3), uname says $(uname -m))"

    log_ok "toolchain ready: ${id} -> ${prefix}"
    printf '%s\n' "${prefix}"
}

# toolchain_env <toolchain_id_or_prefix> -> exports CROSS_COMPILE / tool vars
#
# Accepts either a row id from data/toolchains.tsv or an already-resolved
# prefix directory, so CI can pin a prefix from a cache step without the
# lookup table being available.
toolchain_env() {
    local id_or_prefix=$1 prefix triple
    if [[ -d "${id_or_prefix}" ]]; then
        prefix=$(abspath "${id_or_prefix}")
        triple=$(ls "${prefix}/bin/" 2>/dev/null | sed -n 's/^\(aarch64[a-z0-9-]*\)-gcc$/\1/p' | head -1)
        [[ -n "${triple}" ]] || die "cannot infer gcc triple from ${prefix}/bin"
    else
        triple=$(tc_field "${id_or_prefix}" 8)
        prefix=$(fetch_toolchain "${id_or_prefix}")
    fi
    printf '%s\n' "CROSS_COMPILE=${triple}-"
    printf '%s\n' "TOOLCHAIN_PREFIX=${prefix}"
    printf '%s\n' "TOOLCHAIN_TRIPLE=${triple}"
}

# Does this host already have a usable toolchain, so we can skip the download?
host_toolchain_prefix() {
    local cc
    for cc in aarch64-linux-gnu- aarch64-none-linux-gnu- aarch64-none-elf-; do
        if have "${cc}gcc"; then
            printf '%s\n' "${cc}"
            return 0
        fi
    done
    return 1
}
