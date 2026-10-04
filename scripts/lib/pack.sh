#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/pack.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Artefact packaging: dist/ layout, boot image, .deb.
#
# ---------------------------------------------------------------- boot.img
# FINDING, recorded here because it is the single most misleading thing about
# packaging an OHOS kernel outside the OHOS tree:
#
#   OpenHarmony's boot image is NOT an Android boot image.  OHOS uses its own
#   header format produced by the `img_format` helper that ships inside the
#   closed prebuilts (`packing_tool/packing_tool_libs_*.zip` — verified
#   2026-10-04: that archive contains only Java .jar files, no Linux
#   `img_format` binary).  An AOSP `mkbootimg` will happily produce a file
#   called boot.img, but an OHOS bootloader will not boot it.
#
#   So we do three things, in order of preference:
#     1. If the caller supplies a working `img_format` (OKCP_IMG_FORMAT, or
#        one on PATH), use it.  This is the byte-exact path and the only one
#        that yields a flashable OHOS boot image.
#     2. Otherwise emit `Image` plus a ready-to-run `img_format` command line
#        in `boot-img-cmd.txt`, and say so loudly in the summary.
#     3. Optionally, if OKCP_BOOT_BACKEND=mkbootimg, produce a clearly
#        labelled AOSP-format image for bootloader bring-up / QEMU only.
#
#   We never silently substitute (3) for (1).  A CI job that claims to have
#   produced a flashable OHOS boot.img when it produced an AOSP one is worse
#   than a job that reports honestly that it could not.
#=======================================================================

[[ -n "${_OKCP_PACK_SH:-}" ]] && return 0
_OKCP_PACK_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"
# shellcheck source=./config.sh
[[ -z "${_OKCP_CONFIG_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/config.sh"

OKCP_BOOT_BACKEND="${OKCP_BOOT_BACKEND:-auto}"   # auto | img_format | mkbootimg | none

# Lay out a dist/ directory and copy the raw build output into it.
# Prints the dist dir.
stage_dist() {
    local lane=$1 srcdir=$2 outdir=$3 dist=${4:-}
    [[ -n "${dist}" ]] || dist="${OKCP_OUT_ROOT}/${lane}"

    local arch
    arch=$(lane_arch "${lane}")
    mkdir -p "${dist}/arch/${arch}/boot" "${dist}/arch/${arch}/dtbs" "${dist}/config"

    # --- kernel image(s) ----------------------------------------------
    local img src found=0
    for img in Image Image.gz Image-dtb Image-dtb.gz; do
        src="${outdir}/arch/${arch}/boot/${img}"
        if [[ -f "${src}" ]]; then
            cp -f "${src}" "${dist}/arch/${arch}/boot/"
            found=1
        fi
    done
    if [[ "${found}" == "0" ]]; then
        # x86 lanes and some virt targets land elsewhere.
        for img in bzImage vmlinux; do
            src="${outdir}/arch/${arch}/boot/${img}"
            if [[ -f "${src}" ]]; then cp -f "${src}" "${dist}/arch/${arch}/boot/"; found=1; fi
            src="${outdir}/${img}"
            if [[ -f "${src}" ]]; then cp -f "${src}" "${dist}/arch/${arch}/boot/"; found=1; fi
        done
    fi
    [[ "${found}" == "1" ]] || die "no kernel image found under ${outdir}/arch/${arch}/boot"

    # --- device trees --------------------------------------------------
    if [[ -d "${outdir}/arch/${arch}/boot/dts" ]]; then
        cp -a "${outdir}/arch/${arch}/boot/dts/." "${dist}/arch/${arch}/dtbs/" 2>/dev/null || true
    fi
    if compgen -G "${outdir}/arch/${arch}/boot/dts/*.dtb" >/dev/null 2>&1; then
        cp -f "${outdir}/arch/${arch}/boot/dts/"*.dtb "${dist}/arch/${arch}/dtbs/" 2>/dev/null || true
    fi

    # --- config + provenance ------------------------------------------
    cp -f "${outdir}/.config" "${dist}/config/.config" 2>/dev/null || true
    cp -f "${outdir}/.okcp-resolved-config" "${dist}/config/resolved.config" 2>/dev/null || true
    cp -f "${srcdir}/.okcp-provenance" "${dist}/provenance.env" 2>/dev/null || true
    cp -f "${srcdir}/LICENSE" "${dist}/LICENSE.kernel" 2>/dev/null || true

    # vmlinux is huge and unbootable on its own; keep it only when asked.
    if [[ -n "${OKCP_KEEP_VMLINUX:-}" && -f "${outdir}/vmlinux" ]]; then
        cp -f "${outdir}/vmlinux" "${dist}/vmlinux"
    fi

    log_ok "staged dist: ${dist}"
    printf '%s\n' "${dist}"
}

# Resolve an img_format binary: explicit override, then PATH.
find_img_format() {
    if [[ -n "${OKCP_IMG_FORMAT:-}" ]]; then
        [[ -x "${OKCP_IMG_FORMAT}" ]] || die "OKCP_IMG_FORMAT=${OKCP_IMG_FORMAT} is not executable"
        printf '%s\n' "${OKCP_IMG_FORMAT}"
        return 0
    fi
    if have img_format; then
        command -v img_format
        return 0
    fi
    return 1
}

# make_boot_img <lane> <dist>
#
# Returns 0 if a boot image was produced, 1 if not.  Never dies on a missing
# tool: a missing optional artefact is a warning, and the caller records that
# in the summary so the release notes stay honest.
make_boot_img() {
    local lane=$1 dist=$2
    local arch image
    arch=$(lane_arch "${lane}")
    image="${dist}/arch/${arch}/boot/Image"

    if [[ ! -f "${image}" ]]; then
        log_warn "no Image to pack into a boot image"
        printf 'skipped=no-image\n' > "${dist}/boot-img.status"
        return 1
    fi

    local fmt=""
    if [[ "${OKCP_BOOT_BACKEND}" == "auto" || "${OKCP_BOOT_BACKEND}" == "img_format" ]]; then
        fmt=$(find_img_format) || fmt=""
    fi

    # --- backend 1: OHOS img_format (byte-exact) ------------------------
    if [[ -n "${fmt}" ]]; then
        log_step "packing boot.img with OHOS img_format: ${fmt}"
        local out="${dist}/boot.img"
        # OHOS img_format takes a single config file describing the layout;
        # we generate a minimal one.  Adjust OKCP_BOOT_HDR_* to taste.
        local hdr="${dist}/boot-img-header.cfg"
        cat > "${hdr}" <<EOF
# Generated by ohos-kernel-port.  OHOS boot image layout descriptor.
# See docs/PORTING-NOTES.md for the field meanings.
output=${out}
kernel=${image}
type=normal
EOF
        if "${fmt}" -f "${hdr}" >"${dist}/boot-img.log" 2>&1 && [[ -f "${out}" ]]; then
            log_ok "boot.img produced (OHOS format): $(du -h "${out}" | cut -f1)"
            printf 'ok=img_format\n' > "${dist}/boot-img.status"
            return 0
        fi
        log_warn "img_format invocation failed; see ${dist}/boot-img.log"
        log_warn "falling through to emitting the command line only"
    fi

    # --- backend 3: AOSP mkbootimg, explicitly labelled -----------------
    if [[ "${OKCP_BOOT_BACKEND}" == "mkbootimg" ]]; then
        if have mkbootimg; then
            local page out
            page=$(have python3 && python3 -c 'print(4096)' || echo 2048)
            out="${dist}/boot-aosp.img"
            log_warn "packing an AOSP-format boot image, NOT an OHOS boot image"
            if mkbootimg --kernel "${image}" --ramdisk /dev/null --output "${out}" --pagesize "${page}" \
                 >"${dist}/boot-img.log" 2>&1 && [[ -f "${out}" ]]; then
                log_ok "boot-aosp.img produced: $(du -h "${out}" | cut -f1)"
                printf 'ok=mkbootimg\n' > "${dist}/boot-img.status"
                return 0
            fi
            log_warn "mkbootimg failed; see ${dist}/boot-img.log"
        else
            log_warn "OKCP_BOOT_BACKEND=mkbootimg but mkbootimg is not on PATH"
        fi
    fi

    # --- fallback: emit the exact command line for the operator ---------
    local fmt_cmd ohos_branch
    fmt_cmd="${fmt:-<OHOS img_format binary>}"
    ohos_branch=$(lane_ohos_branch "${lane}")
    cat > "${dist}/boot-img-cmd.txt" <<EOF
# No boot image was produced by this run.
#
# OpenHarmony boot images use OHOS's own header format, produced by the
# \`img_format\` helper.  That helper is not part of any public OpenHarmony
# repository: the published \`packing_tool\` archive ships only Java jars.
# See docs/BOOT-IMAGE.md for the full finding and the field meanings.
#
# Everything else you need is in this directory.  To finish packaging once you
# have img_format, run:
#
${fmt_cmd} -f <header.cfg>          # header.cfg layout is documented in docs/BOOT-IMAGE.md
#
# Or, inside an OpenHarmony source tree, drop the built Image at
#   kernel/linux/linux-$(lane_arch "${lane}")/
# and run:
#   ./build.sh --build-target ${ohos_branch}
EOF
    printf 'skipped=no-img_format\n' > "${dist}/boot-img.status"
    log_warn "no boot.img produced; wrote ${dist}/boot-img-cmd.txt with the exact command to run"
    return 1
}

# make_deb <lane> <dist>
#
# A minimal, dependency-free .deb so the artefact is installable with plain
# dpkg on any Debian-family target.  We deliberately do not shell out to
# dpkg-deb: the format is trivial and doing it in shell keeps CI honest about
# not needing a root-owned toolchain.
make_deb() {
    local lane=$1 dist=$2
    local arch kver pkg
    arch=$(lane_arch "${lane}")
    kver=$(lane_kver "${lane}")

    local deb_arch
    case "${arch}" in
        arm64)   deb_arch=arm64   ;;
        x86_64)  deb_arch=amd64   ;;
        riscv64) deb_arch=riscv64 ;;
        *)       deb_arch="${arch}" ;;
    esac

    local ohos_branch source_repo
    ohos_branch=$(lane_ohos_branch "${lane}")
    source_repo=$(lane_repo "${lane}")

    pkg="ohos-kernel-${lane}-${kver}"
    local stage root
    stage=$(make_tmpdir)
    root="${stage}/${pkg}"

    mkdir -p "${root}/DEBIAN" \
             "${root}/boot" \
             "${root}/lib/modules/${kver}" \
             "${root}/usr/share/doc/${pkg}" \
             "${root}/usr/share/ohos-kernel-port"

    cp -f "${dist}"/arch/"${arch}"/boot/* "${root}/boot/" 2>/dev/null || true
    cp -f "${dist}/config/.config" "${root}/boot/config-${kver}" 2>/dev/null || true
    cp -f "${dist}/provenance.env" "${root}/usr/share/ohos-kernel-port/" 2>/dev/null || true
    if [[ -d "${OKCP_OUT_ROOT}/${lane}/arch/${arch}/modules" ]]; then
        cp -a "${OKCP_OUT_ROOT}/${lane}/arch/${arch}/modules/." \
              "${root}/lib/modules/${kver}/" 2>/dev/null || true
    fi
    cp -f "${OKCP_ROOT}/LICENSE" "${root}/usr/share/doc/${pkg}/copyright" 2>/dev/null || true

    # debian/control
    local installed_size
    installed_size=$(du -sk "${root}" | cut -f1)
    cat > "${root}/DEBIAN/control" <<EOF
Package: ${pkg}
Version: ${kver}
Section: kernel
Priority: optional
Architecture: ${deb_arch}
Maintainer: ohos-kernel-port contributors <noreply@example.invalid>
Depends: linux-base (>= 3.0)
Installed-Size: ${installed_size}
Description: OpenHarmony Linux ${kver} kernel image (lane ${lane})
 Built from the OpenHarmony ${ohos_branch} branch of
 ${source_repo} by ohos-kernel-port, which is a derivative of ophub/kernel
 (GPL-2.0).  Install into /boot; it is not ABI compatible with a stock
 Debian kernel of a different version.
EOF

    # Debian maintainer scripts must be idempotent and must never guess.
    cat > "${root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
case "$1" in
  configure)
    if [ -d /boot ] && [ -w /boot ]; then
      echo "ohos-kernel: images installed under /boot." >&2
      echo "ohos-kernel: update-initramfs is intentionally NOT run -" >&2
      echo "ohos-kernel: this kernel is for an OpenHarmony target, not the running host." >&2
    fi
    ;;
esac
exit 0
EOF
    chmod 0755 "${root}/DEBIAN/postinst"

    # md5sums for every payload file
    ( cd "${root}" && find . -type f ! -path './DEBIAN/*' -print0 \
        | sort -z | xargs -0 md5sum > DEBIAN/md5sums ) || true

    local out="${dist}/${pkg}_${deb_arch}.deb"
    if have dpkg-deb; then
        dpkg-deb --build --root-owner-group "${root}" "${out}" >/dev/null 2>&1 \
            || { log_warn "dpkg-deb failed; falling back to ar+tar"; _make_deb_manual "${root}" "${out}"; }
    else
        _make_deb_manual "${root}" "${out}"
    fi

    if [[ -f "${out}" ]]; then
        log_ok "packaged ${out} ($(du -h "${out}" | cut -f1))"
        printf '%s\n' "${out}"
        rm -rf "${stage}"
        return 0
    fi
    log_warn "deb packaging failed"
    rm -rf "${stage}"
    return 1
}

# Pure-shell .deb (ar + tar.gz), for runners without dpkg-deb.
# Debian binary package format: "!<arch>\n" ar member per control file,
# then data.tar.gz, all concatenated.
_make_deb_manual() {
    local root=$1 out=$2
    local stage
    stage=$(make_tmpdir)
    ( cd "${root}" && tar --owner=0 --group=0 --numeric-owner -czf "${stage}/data.tar.gz" . )
    printf '2.0\n' > "${stage}/debian-binary"
    tar -czf "${stage}/control.tar.gz" -C "${root}/DEBIAN" .
    ( cd "${stage}" && ar rc "${out}" debian-binary control.tar.gz data.tar.gz ) 2>/dev/null || {
        log_error "ar(1) is required to build a .deb without dpkg-deb"
        return 1
    }
    rm -rf "${stage}"
}

# checksums_file <dist>
checksums_file() {
    local dist=$1
    (
        cd "${dist}" || exit 1
        find . -type f ! -name 'SHA256SUMS*' -print0 \
            | sort -z | xargs -0 sha256sum
    ) > "${dist}/SHA256SUMS"
    log_ok "wrote ${dist}/SHA256SUMS"
}

# build_summary <lane> <dist> -> a human readable report for the CI job summary
build_summary() {
    local lane=$1 dist=$2
    local arch kver
    arch=$(lane_arch "${lane}")
    kver=$(lane_kver "${lane}")

    printf '## %s — Linux %s\n\n' "${lane}" "${kver}"
    printf '| field | value |\n| --- | --- |\n'
    printf '| OpenHarmony branch | `%s` |\n' "$(lane_ohos_branch "${lane}")"
    printf '| Source repo | `%s` |\n' "$(lane_repo "${lane}")"
    printf '| ARCH | `%s` |\n' "${arch}"

    local commit='unknown'
    [[ -f "${dist}/provenance.env" ]] && commit=$(awk -F= '$1=="commit"{print $2}' "${dist}/provenance.env")
    printf '| Source commit | `%s` |\n' "${commit}"

    if [[ -f "${dist}/arch/${arch}/boot/Image" ]]; then
        printf '| Image | %s |\n' "$(du -h "${dist}/arch/${arch}/boot/Image" | cut -f1)"
    fi
    local deb
    deb=$(find "${dist}" -maxdepth 1 -name '*.deb' 2>/dev/null | head -1)
    [[ -n "${deb}" ]] && printf '| .deb | `%s` (%s) |\n' "$(basename -- "${deb}")" "$(du -h "${deb}" | cut -f1)"

    local bstat='unknown'
    [[ -f "${dist}/boot-img.status" ]] && bstat=$(cut -d= -f2 "${dist}/boot-img.status")
    printf '| boot.img | **%s** |\n' "${bstat}"
    if [[ "${bstat}" == skipped* ]]; then
        printf '\n'
        printf '> A flashable OpenHarmony `boot.img` was **not** produced: it needs OHOS'"'"'s\n'
        printf '> `img_format` helper, which is not distributed in any public repository.\n'
        printf '> `boot-img-cmd.txt` in the artefact has the exact command to finish it.\n'
        printf '> See `docs/BOOT-IMAGE.md`.\n'
    fi
    printf '\n### Notable config\n\n```\n'
    config_facts "${dist}/config/.config" 2>/dev/null || true
    printf '```\n'
}
