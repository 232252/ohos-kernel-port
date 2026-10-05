#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/build.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# kbuild invocation.
#
# Structurally identical to ophub's `make -j$(nproc)` step; the differences
# are (a) an explicit O= out-of-tree build dir so the checkout stays clean and
# ccache is reusable across lanes, and (b) a ccache wrapper that CI can turn
# on without a distro package for the cross compiler.
#=======================================================================

[[ -n "${_OKCP_BUILD_SH:-}" ]] && return 0
_OKCP_BUILD_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"
# shellcheck source=./config.sh
[[ -z "${_OKCP_CONFIG_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/config.sh"

# Follow OKCP_WORKDIR so a CI run that mounted a large volume actually
# uses it; a 6.6 arm64 build does not fit in a hosted runner's workspace.
OKCP_OUT_ROOT="${OKCP_OUT_ROOT:-${OKCP_WORKDIR:-${OKCP_ROOT}/build}/out}"
OKCP_CCACHE_DIR="${OKCP_CCACHE_DIR:-${OKCP_ROOT}/build/ccache}"

# Assemble the kbuild arguments shared by every make call in a lane.
# Prints one argument per line on stdout so callers can splat safely.
kbuild_args() {
    local srcdir=$1 outdir=$2 arch=$3
    local -a a=(
        -C "${srcdir}"
        "O=${outdir}"
        "ARCH=${arch}"
    )
    if [[ -n "${OKCP_CROSS_COMPILE:-}" ]]; then
        a+=("CROSS_COMPILE=${OKCP_CROSS_COMPILE}")
    fi
    if [[ -n "${OKCP_CLANG:-}" ]]; then
        # The OHOS tree's Makefile already understands LLVM=; use the
        # upstream-supported spelling rather than overriding CC/LD by hand.
        a+=("LLVM=1" "LLVM_IAS=1" "CC=${OKCP_CLANG}")
    fi
    if [[ -n "${OKCP_KBUILD_JLEVEL:-}" ]]; then
        a+=("-j${OKCP_KBUILD_JLEVEL}")
    fi
    if [[ -n "${OKCP_EXTRA_MAKE_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        local -a extra=(${OKCP_EXTRA_MAKE_ARGS})
        a+=("${extra[@]}")
    fi
    printf '%s\n' "${a[@]}"
}

# Install a ccache shim for the cross compiler when ccache is available.
# Returns 0 if a shim is in place, 1 if not (caller just proceeds without).
setup_ccache() {
    [[ -n "${OKCP_CROSS_COMPILE:-}" ]] || return 1
    have ccache || { log_debug "ccache not installed; building without it"; return 1; }
    [[ -n "${OKCP_USE_CCACHE:-}" ]] || return 1

    local bindir="${OKCP_ROOT}/build/.ccache-shim"
    local real="${OKCP_TOOLCHAIN_PREFIX:-}/bin/${OKCP_CROSS_COMPILE}gcc"
    if [[ ! -x "${real}" ]]; then
        # Cross toolchain not in the standard layout (system compiler, LLVM
        # mode).  kbuild handles ccache itself via the CC="ccache gcc" form
        # when we set OKCP_CCACHE_INLINE=1, so there is nothing to shim.
        return 1
    fi
    mkdir -p "${bindir}"
    local shim="${bindir}/${OKCP_CROSS_COMPILE}gcc"
    cat > "${shim}" <<EOF
#!/bin/sh
exec ccache "${real}" "\$@"
EOF
    chmod +x "${shim}"
    export PATH="${bindir}:${PATH}"
    export CCACHE_DIR="${OKCP_CCACHE_DIR}"
    mkdir -p "${OKCP_CCACHE_DIR}"
    log_step "ccache shim installed: ${shim} (CCACHE_DIR=${OKCP_CCACHE_DIR})"
    return 0
}

# build_kernel <lane> <srcdir> <outdir>
#
# Runs the Image target, then (best effort) the DTBs.  A DTB failure is not
# fatal: a large fraction of real OHOS targets have no DT at all because the
# bootloader passes the device tree, and refusing to produce an Image over it
# would be wrong.
build_kernel() {
    local lane=$1 srcdir=$2 outdir=${3:-$(lane_outdir "${lane}")}
    local arch
    arch=$(lane_arch "${lane}")
    mkdir -p "${outdir}"

    local -a args
    mapfile -t args < <(kbuild_args "${srcdir}" "${outdir}" "${arch}")

    local t0 t1
    t0=$(date +%s)

    log_step "building ${lane} (Linux $(lane_kver "${lane}"), ARCH=${arch}, -j${OKCP_JOBS})"
    log_info "log: ${outdir}/build.log"

    # ccache only helps if it is in front of the compiler.  The kernel calls
    # $(CC) for nearly every object, so this single shim covers the build.
    if [[ -n "${OKCP_USE_CCACHE:-}" && -z "${OKCP_CLANG:-}" ]]; then
        if ! setup_ccache; then
            # Fall back to kbuild's own CC wrapping.
            have ccache || log_warn "ccache requested but not installed; continuing without it"
        fi
    fi

    # OKCP_KEEP_GOING=1 adds make -k, which keeps building after an error
    # instead of stopping at the first one.  This tree turns out to reference
    # several files that were never published, and without -k each one costs a
    # ten-minute CI round trip to discover.  With it, one run reports them all.
    if [[ -n "${OKCP_KEEP_GOING:-}" ]]; then
        args+=(-k)
        log_info "diagnosis mode: make -k, so every error is reported in this run"
    fi

    if ! ( cd "${srcdir}" && make "${args[@]}" Image ) > >(tee "${outdir}/build.log") 2>&1; then
        log_error "kernel build FAILED. Last 40 lines of ${outdir}/build.log:"
        tail -40 "${outdir}/build.log" >&2 || true
        # A missing file is the common failure here, so collect them all rather
        # than leaving the reader to grep.
        if grep -q "No such file or directory" "${outdir}/build.log"; then
            log_error "--- every missing file this build reported ---"
            grep -oE "[^ :]+: (fatal error: [^:]+|No such file or directory)" "${outdir}/build.log" \
                | sort -u | sed 's/^/    /' >&2
            log_error "---------------------------------------"
            log_error "  add a shim or remove the reference, then re-run with"
            log_error "  --keep-going to see what else is missing."
        fi
        return 1
    fi

    # DTBs are best effort; record whether we got them.
    if ( cd "${srcdir}" && make "${args[@]}" dtbs ) >>"${outdir}/build.log" 2>&1; then
        log_ok "dtbs built"
        printf 'dtbs=ok\n' >> "${outdir}/.okcp-build-meta"
    else
        log_warn "dtbs target failed; continuing (many OHOS targets get their DTB from the bootloader)"
        log_warn "  see ${outdir}/build.log"
        printf 'dtbs=failed\n' >> "${outdir}/.okcp-build-meta"
    fi

    t1=$(date +%s)
    printf 'seconds=%s\n' "$((t1 - t0))" >> "${outdir}/.okcp-build-meta"
    printf 'arch=%s\n'    "${arch}"      >> "${outdir}/.okcp-build-meta"

    # --- verify we actually got an image -------------------------------
    if [[ ! -f "${outdir}/arch/${arch}/boot/Image" ]]; then
        log_error "build reported success but ${outdir}/arch/${arch}/boot/Image does not exist"
        return 1
    fi

    log_ok "built Image in $(fmt_duration $((t1 - t0))): $(du -h "${outdir}/arch/${arch}/boot/Image" | cut -f1)"
}

# build_modules <lane> <srcdir> <outdir>
# Needed for the .deb package; a no-op when the config has no modules.
build_modules() {
    local lane=$1 srcdir=$2 outdir=$3
    local arch
    arch=$(lane_arch "${lane}")
    grep -qx 'CONFIG_MODULES=y' "${outdir}/.config" 2>/dev/null || {
        log_info "CONFIG_MODULES is not set; skipping modules"
        return 0
    }
    local -a args
    mapfile -t args < <(kbuild_args "${srcdir}" "${outdir}" "${arch}")
    log_step "building modules"
    ( cd "${srcdir}" && make "${args[@]}" modules ) >>"${outdir}/build.log" 2>&1 \
        || { log_error "module build failed; see ${outdir}/build.log"; return 1; }
    log_ok "modules built"
}

# Append a LOCALVERSION suffix and re-derive the configuration.
#
# Opt-in only.  OpenHarmony does not select kernels by version string, so an
# injected suffix is a gratuitous difference from the release a lane tracks.
# Usage: stamp_version <srcdir> <suffix> [arch]
stamp_version() {
    local srcdir=$1 suffix=$2 arch=${3:-}
    if [[ -z "${suffix}" ]]; then
        log_debug "no version suffix requested"
        return 0
    fi
    [[ -n "${arch}" ]] || arch=$(lane_arch "${LANE:-primary}")
    log_step "stamping the kernel version with '${suffix}'"
    printf '\nCONFIG_LOCALVERSION="%s"\n' "${suffix}" >> "${srcdir}/.config"
    ( cd "${srcdir}" && make -s ARCH="${arch}" olddefconfig ) >/dev/null 2>&1 \
        || log_warn "olddefconfig after stamping exited non-zero (continuing)"
    local v
    v=$( cd "${srcdir}" && make -s ARCH="${arch}" kernelversion 2>/dev/null || echo '?' )
    log_ok "kernel version is now: ${v}"
}

# The toolchain variables the CLI must set before build_kernel, and the
# compiler we will actually use, for reporting.
build_toolchain_summary() {
    printf 'CROSS_COMPILE=%s\n' "${OKCP_CROSS_COMPILE:-<native>}"
    printf 'CC=%s\n'           "${OKCP_CLANG:-aarch64 gcc via ${OKCP_CROSS_COMPILE:-host}}"
}
