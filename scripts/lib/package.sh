#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/package.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Artifact production.
#
# Two packaging backends, selected by OKCP_PACKAGER:
#
#   ohos     delegate to OpenHarmony's own kernel_linux_build/build_kernel.sh,
#            so our output is byte-comparable with a stock OpenHarmony build
#   standalone  pack with the tools we can obtain ourselves, for hosts that do
#            not have a full OpenHarmony source tree (this is the path CI uses
#            for fast lanes and artifact-only builds)
#
# The standalone backend's boot.img layout is parameterised because
# OpenHarmony's exact mkbootimg arguments differ per board (partition size,
# page size, ramdisk, boot-upstream vs boot).  Defaults follow the
# arm64/rk3568-style layout; override with OKCP_BOOTIMG_ARGS for other boards.
#=======================================================================

[[ -n "${_OKCP_PACKAGE_SH:-}" ]] && return 0
_OKCP_PACKAGE_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"
# shellcheck source=./pack.sh
# pack.sh owns boot.img; see its header for why an AOSP mkbootimg is not an
# acceptable silent substitute for OpenHarmony's img_format.
[[ -z "${_OKCP_PACK_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/pack.sh"

OKCP_PACKAGER="${OKCP_PACKAGER:-standalone}"
# Follow OKCP_WORKDIR like OKCP_OUT_ROOT does.  It did not, so a CI run that
# mounts a large volume at /builder wrote its build output there and its
# artifacts in the workspace, and the artifact-upload step looked in /builder
# and found nothing:
#   ##[error]No files were found with the provided path
OKCP_ARTIFACT_DIR="${OKCP_ARTIFACT_DIR:-${OKCP_WORKDIR:-${OKCP_ROOT}/build}/artifacts}"

#--------------------------------------------------------------- small utils
# Kernel version straight out of a source tree's top-level Makefile.
kernel_version_of() {
    local srcdir=$1
    require_file "${srcdir}/Makefile"
    awk '
        /^VERSION *=/    { v=$3 }
        /^PATCHLEVEL *=/ { p=$3 }
        /^SUBLEVEL *=/   { s=$3 }
        END { if (v != "" && p != "" && s != "") printf "%s.%s.%s\n", v, p, s }
    ' "${srcdir}/Makefile"
}

# collect_kernel_headers <srcdir> <kbuild_outdir> <arch> <dest>
#
# Stage a `make modules_prepare` header tree so downstream out-of-tree modules
# (OpenHarmony's kernel_linux_common_modules drivers) can be built against
# this kernel.  This is ported from ophub's collect_headers() and is the piece
# that makes the artefact useful to the OHOS userspace rather than just to a
# bootloader.


#--------------------------------------------------------------- metadata
# Every artifact set ships a manifest recording exactly what produced it.
# Reproducibility and license provenance both depend on this.
write_artifact_manifest() {
    local lane=$1 srcdir=$2 outdir=$3 kver=$4
    local prov="${srcdir}/.okcp-provenance"
    local src_url='unknown' src_branch='unknown' src_commit='unknown'
    if [[ -f "${prov}" ]]; then
        # shellcheck disable=SC1090
        while IFS='=' read -r k v; do
            case "${k}" in
                source_url)   src_url=${v} ;;
                branch)       src_branch=${v} ;;
                commit)       src_commit=${v} ;;
            esac
        done < "${prov}"
    fi
    cat > "${outdir}/MANIFEST.txt" <<EOF
# ohos-kernel-port artifact manifest
# SPDX-License-Identifier: GPL-2.0

lane              : ${lane}
kernel version    : ${kver}
openharmony branch: ${src_branch}
source url        : ${src_url}
source commit     : ${src_commit}
system type       : ${OKCP_SYSTEM_TYPE:-standard}
board             : ${OKCP_BOARD:-<none>}
packager          : ${OKCP_PACKAGER}
built at          : $(date -u +%Y-%m-%dT%H:%M:%SZ)
built with        : ${OKCP_CC_PATH:-unknown} (arch ${OKCP_TARGET_ARCH:-arm64})
built by          : ohos-kb (derived from ophub/kernel, GPL-2.0)

This kernel is free software under the GNU General Public License version 2
or (at your option) any later version.  The corresponding source is available
at ${src_url} (branch ${src_branch}, commit ${src_commit}) and the build
scripts that produced these binaries are in this repository.
EOF
    log_ok "manifest: ${outdir}/MANIFEST.txt"
}

#------------------------------------------------------------- ohos backend
# Run OpenHarmony's own build_kernel.sh.  Requires OKCP_OHOS_BUILD_REPO to be a
# checkout of kernel_linux_build, and the full OpenHarmony source tree layout.
package_ohos() {
    local lane=$1 srcdir=$2 outdir=${3:-${OKCP_ARTIFACT_DIR}/${lane}}
    local build_repo=${OKCP_OHOS_BUILD_REPO:-}

    [[ -n "${build_repo}" ]] || die "OKCP_PACKAGER=ohos needs OKCP_OHOS_BUILD_REPO=<path to kernel_linux_build checkout>"
    require_file "${build_repo}/build_kernel.sh"

    mkdir -p "${outdir}"
    log_step "delegating to OpenHarmony build_kernel.sh"
    log_info "build repo: ${build_repo}"
    log_info "kernel src: ${srcdir}"

    # OHOS' script derives most paths from its own location; we pass the
    # override variables it honours and let it do the rest.
    (
        export KERNEL_SRC_DIR="${srcdir}"
        export OUTPUT_DIR="${outdir}"
        export ARCH="${OKCP_TARGET_ARCH:-arm64}"
        [[ -n "${OKCP_BOARD}" ]] && export KERNEL_BOARD="${OKCP_BOARD}"
        cd "${build_repo}" && ./build_kernel.sh
    ) || { log_error "build_kernel.sh failed"; return 1; }

    log_ok "OpenHarmony packager produced artifacts in ${outdir}"
    printf '%s\n' "${outdir}"
}

#--------------------------------------------------------- kernel headers
# Install the header set an out-of-tree module build needs: Kbuild files, the
# generated configuration, Module.symvers, and any gcc plugins.
#   collect_kernel_headers <srcdir> <kbuild> <arch> <dest>
# Ported from ophub's collect_headers() (armbian_compile_kernel.sh:540).
collect_kernel_headers() {
    local srcdir=$1 kbuild=$2 arch=$3 dest=$4
    mkdir -p "${dest}"

    # Text headers: build system, includes, arch glue.
    local head_list obj_list
    head_list=$(make_tmpdir)/head.list
    obj_list=$(make_tmpdir)/obj.list
    mkdir -p "$(dirname -- "${head_list}")" "$(dirname -- "${obj_list}")"

    {
        find "${srcdir}/arch/${arch}" -maxdepth 1 -name 'Makefile*' -print
        find "${srcdir}/include" "${srcdir}/scripts" -type f -o -type l 2>/dev/null
        find "${srcdir}/arch/${arch}" \( -name Kbuild.platforms -o -name Platform \) -print 2>/dev/null
        find "${srcdir}/arch/${arch}" \( -name include -o -name scripts \) -type d -exec find {} -type f \; 2>/dev/null
    } | sed "s|^${srcdir}/||" | sort -u > "${head_list}"

    {
        grep -q '^CONFIG_OBJTOOL=y' "${srcdir}/include/config/auto.conf" 2>/dev/null && echo 'tools/objtool/objtool'
        find "${srcdir}/arch/${arch}/include" "${srcdir}/Module.symvers" \
             "${srcdir}/include" "${srcdir}/scripts" -type f 2>/dev/null | sed "s|^${srcdir}/||"
        grep -q '^CONFIG_GCC_PLUGINS=y' "${srcdir}/include/config/auto.conf" 2>/dev/null && \
            find "${srcdir}/scripts/gcc-plugins" -name '*.so' 2>/dev/null | sed "s|^${srcdir}/||"
    } | sort -u > "${obj_list}"

    # Objects come from the build output tree, headers from the source tree.
    [[ -s "${head_list}" ]] && tar -C "${srcdir}" -cf - -T "${head_list}" 2>/dev/null | tar -C "${dest}" -xf - 2>/dev/null
    [[ -s "${obj_list}" ]] && tar -C "${kbuild}" -cf - -T "${obj_list}" 2>/dev/null | tar -C "${dest}" -xf - 2>/dev/null

    cp -af "${srcdir}/include/config"   "${dest}/include" 2>/dev/null || true
    cp -af "${srcdir}/include/generated" "${dest}/include" 2>/dev/null || true
    cp -af "${srcdir}/arch/${arch}/include/generated" "${dest}/arch/${arch}/include" 2>/dev/null || true
    [[ -f "${kbuild}/.config" ]]     && cp -af "${kbuild}/.config"     "${dest}/" 2>/dev/null || true
    [[ -f "${kbuild}/Module.symvers" ]] && cp -af "${kbuild}/Module.symvers" "${dest}/" 2>/dev/null || true

    rm -rf "$(dirname -- "${head_list}")"
    # An empty header dir means the collection silently failed; say so rather
    # than shipping a broken one.
    [[ -f "${dest}/Makefile" || -d "${dest}/include" ]]
}

#------------------------------------------------------ standalone backend
package_standalone() {
    local lane=$1 srcdir=$2 outdir=${3:-${OKCP_ARTIFACT_DIR}/${lane}}
    local kbuild="${srcdir}/${OKCP_KBUILD_OUT:-out}"
    local arch=${OKCP_TARGET_ARCH:-arm64}
    mkdir -p "${outdir}"

    #-- 1. raw kernel artifacts -------------------------------------------
    local f dst
    for f in \
        "${kbuild}/arch/${arch}/boot/Image" \
        "${kbuild}/vmlinux" \
        "${kbuild}/System.map" \
        "${kbuild}/.config" \
        "${kbuild}/include/generated/utsrelease.h"
    do
        if [[ -f "${f}" ]]; then
            dst="${outdir}/$(basename -- "${f}")"
            cp -f "${f}" "${dst}"
            log_debug "collected $(basename -- "${f}")"
        fi
    done

    if [[ -d "${kbuild}/arch/${arch}/boot/dts" ]]; then
        mkdir -p "${outdir}/dtbs"
        find "${kbuild}/arch/${arch}/boot/dts" -name '*.dtb' -exec cp -f {} "${outdir}/dtbs/" \; 2>/dev/null || true
        local nd
        nd=$(find "${outdir}/dtbs" -name '*.dtb' 2>/dev/null | wc -l)
        [[ "${nd}" -gt 0 ]] && log_ok "collected ${nd} dtb(s)"
    fi

    #-- 2. modules -------------------------------------------------------
    if [[ -d "${kbuild}" ]]; then
        find "${kbuild}" -name '*.ko' -exec cp -f {} "${outdir}/" \; 2>/dev/null || true
        local nk
        nk=$(find "${outdir}" -maxdepth 1 -name '*.ko' 2>/dev/null | wc -l)
        [[ "${nk}" -gt 0 ]] && log_ok "collected ${nk} kernel module(s)"
    fi

    #-- 3. kernel headers (for out-of-tree module development) -----------
    # Ported from ophub's collect_headers().  Without this, building a
    # kernel_linux_common_modules out-of-tree driver is impossible.
    if [[ -f "${kbuild}/Module.symvers" || -d "${srcdir}/include" ]]; then
        if collect_kernel_headers "${srcdir}" "${kbuild}" "${arch}" "${outdir}/header"; then
            log_ok "kernel headers: ${outdir}/header"
        fi
    fi

    #-- 4. boot.img ------------------------------------------------------
    # Delegated to pack.sh:make_boot_img, which owns the backend choice and,
    # more importantly, refuses to pass an AOSP-format image off as a
    # flashable OpenHarmony one.  Here we only supply the ramdisk hint.
    if [[ -f "${outdir}/Image" ]]; then
        if [[ -f "${OKCP_BOOTIMG_RAMDISK}" ]]; then
            OKCP_BOOTIMG_RAMDISK_PATH="${OKCP_BOOTIMG_RAMDISK}" \
                make_boot_img "$(basename -- "$(dirname -- "${outdir}")")" "${outdir}" || true
        else
            log_warn "no ramdisk at ${OKCP_BOOTIMG_RAMDISK}; a kernel-only build cannot"
            log_warn "  produce a bootable OpenHarmony image, so boot.img is skipped"
            log_warn "  (the raw Image is still available in this directory)"
        fi
    fi

    printf '%s\n' "${outdir}"
}

#------------------------------------------------------------- entry point
package_kernel() {
    local lane=$1 srcdir=$2 outdir=${3:-${OKCP_ARTIFACT_DIR}/${lane}}
    local kver; kver=$(kernel_version_of "${srcdir}")

    case "${OKCP_PACKAGER}" in
        ohos)       package_ohos       "${lane}" "${srcdir}" "${outdir}" ;;
        standalone) package_standalone "${lane}" "${srcdir}" "${outdir}" ;;
        *) die "unknown OKCP_PACKAGER='${OKCP_PACKAGER}' (expected ohos|standalone)" ;;
    esac

    write_artifact_manifest "${lane}" "${srcdir}" "${outdir}" "${kver}"
    log_ok "artifacts: ${outdir#"${OKCP_ROOT}"/}"
    printf '%s\n' "${outdir}"
}
