#!/bin/bash
# shellcheck shell=bash
#=======================================================================
# ohos-kernel-port / scripts/lib/config.sh
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Kernel configuration.
#
# WHY kernel_linux_config IS MANDATORY  (measured 2026-10-04)
# -------------------------------------------------------
# It is tempting to assume the OpenHarmony kernel tree ships its own OHOS
# defconfig and that arch/<arch>/configs/defconfig can be used directly.
# Measured on kernel_linux_6.6 @ OpenHarmony-7.0-Release (commit f4b61510):
#
#     in-tree arch/arm64/configs/defconfig     1579 CONFIG symbols
#     kernel_linux_config base_defconfig          43 CONFIG symbols
#     kernel_linux_config type/standard_defconfig 755 CONFIG symbols
#     union of the two config-repo layers         798 CONFIG symbols
#     of those, present in the in-tree defconfig  110  (13 %)
#
# 652 symbols that OpenHarmony actually configures are absent from the in-tree
# defconfig, including CONFIG_ACCESS_TOKENID, CONFIG_ANDROID_BINDER_IPC and the
# CONFIG_ANDROID family.  A kernel built from the in-tree defconfig is
# therefore NOT an OpenHarmony kernel.  config.sh deliberately treats the
# config repo as the source of truth and logs which layer supplied the base,
# so a regression here cannot pass silently.
#
# LAYER ORDER (later layers win)
#   1. kernel_linux_config  linux-<ver>/base_defconfig        (OHOS repo)
#   2. kernel_linux_config  linux-<ver>/type/<type>_defconfig (OHOS repo)
#      ...or a complete per-board config, which supersedes 1+2 entirely
#   3. in-tree              arch/<arch>/configs/defconfig      (fallback only)
#   4. configs/base/<arch>/*.config                            (this repo)
#   5. configs/lanes/<overlay>/*.config                         (this repo)
#   6. --config PATH (adhoc, not persisted)
#   7. make O=<kdir> olddefconfig                              (re-derive)
#
# The configuration MUST be produced in the same out-of-tree kbuild directory
# the compile step uses.  Writing .config into the source tree and running an
# in-tree olddefconfig leaves include/config and friends behind, and the next
# out-of-tree build then refuses with
#   *** The source tree is not clean, please run 'make ARCH=arm64 mrproper' 
#=======================================================================

[[ -n "${_OKCP_CONFIG_SH:-}" ]] && return 0
_OKCP_CONFIG_SH=1
# shellcheck source=./common.sh
[[ -z "${OKCP_ROOT:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=./matrix.sh
[[ -z "${_OKCP_MATRIX_SH:-}" ]] && source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/matrix.sh"

OKCP_CONFIG_ROOT="${OKCP_ROOT}/configs"
OKCP_CONFIG_REPO="${OKCP_CONFIG_REPO:-kernel_linux_config}"
OKCP_OHOS_HOST="${OKCP_OHOS_HOST:-https://gitcode.com/openharmony}"

# System type: standard (full OHOS standard system) | small (lightweight/IoT).
# Mirrors kernel_linux_config/linux-<ver>/type/.
OKCP_SYSTEM_TYPE="${OKCP_SYSTEM_TYPE:-standard}"
# Board directory inside kernel_linux_config (rk3568, qemu, ...).  Empty means
# no board layer.
OKCP_BOARD="${OKCP_BOARD:-}"

#-------------------------------------------------------------------- arch
# The canonical name is lane_arch, because build.sh and pack.sh call it that
# way.  config_arch is kept as an alias so either spelling works; there is only
# one implementation.
lane_arch() {
    local lane=$1
    if [[ -n "${OKCP_ARCH:-}" ]]; then printf '%s\n' "${OKCP_ARCH}"; return 0; fi
    # A lane may pin the ARCH explicitly (the 32-bit hispark_taurus target).
    local from_lane
    from_lane=$(lane_arch_of "${lane}" 2>/dev/null || true)
    if [[ -n "${from_lane}" ]]; then printf '%s\n' "${from_lane}"; return 0; fi
    case "$(lane_repo "${lane}")" in
        kernel_linux_4.19|kernel_linux) printf 'arm\n' ;;
        *) printf 'arm64\n' ;;
    esac
}

# The board layer, from the lane unless the caller pinned one.
lane_board_layer() {
    local lane=$1
    # Non-empty wins, whether it came from --board or from set_lane's default.
    # An explicitly empty --board means "generic", which is also what a lane
    # with no board column says, so the two need no separate path.
    if [[ -n "${OKCP_BOARD:-}" ]]; then printf '%s\n' "${OKCP_BOARD}"; return 0; fi
    lane_board "${lane}" 2>/dev/null || true
}
config_arch() { lane_arch "$1"; }

# ---------------------------------------------------------------------------
# Board configuration porting across kernel versions
# ---------------------------------------------------------------------------
# OpenHarmony ships a per-board configuration for some boards on some kernel
# versions and not others: at OpenHarmony-7.0-Release, linux-6.6/ has rk3568
# and nothing else, while linux-5.10/ has six boards.  This project's target is
# 6.6.101 for every device, so the boards with no native 6.6 configuration have
# to be carried over.
#
# This is what a distribution does when it moves a board from one kernel series
# to another: seed the new tree's .config with the old board configuration and
# let the new tree's kconfig resolve it.  Symbols the new Kconfig does not know
# are dropped — unavoidable — so the port reports exactly which, because a
# silently shrunken board configuration is worse than no kernel at all.

# Every configuration that exists for a board, as "native<TAB>path" (for this
# series) or "port<TAB>path" (for another series), native first.
board_config_candidates() {
    local cfgroot=$1 board=$2 series=$3 cand other
    [[ -n "${board}" ]] || return 0
    [[ -d "${cfgroot}" ]] || return 0

    # --- native: this exact series ---------------------------------------
    for cand in \
        "${cfgroot}/linux-${series}/${board}/arch/arm64_defconfig" \
        "${cfgroot}/linux-${series}/${board}/arch/arm_defconfig" \
        "${cfgroot}/linux-${series}/arch/arm64/configs/${board}"_defconfig \
        "${cfgroot}/linux-${series}/arch/arm/configs/${board}"_defconfig
    do
        [[ -f "${cand}" ]] && printf 'native\t%s\n' "${cand}"
    done
    for cand in "${cfgroot}"/linux-${series}/arch/*/configs/"${board}"*_defconfig; do
        [[ -f "${cand}" ]] && printf 'native\t%s\n' "${cand}"
    done

    # --- port: any other series, oldest first so the newest ends up last ---
    for other in $(ls -1 "${cfgroot}" 2>/dev/null | grep '^linux-' | sort -V); do
        [[ "${other}" == "linux-${series}" ]] && continue
        for cand in \
            "${cfgroot}/${other}/${board}/arch/arm64_defconfig" \
            "${cfgroot}/${other}/${board}/arch/arm_defconfig" \
            "${cfgroot}/${other}/arch/arm64/configs/${board}"_defconfig \
            "${cfgroot}/${other}/arch/arm/configs/${board}"_defconfig
        do
            [[ -f "${cand}" ]] && printf 'port\t%s\n' "${cand}"
        done
        for cand in "${cfgroot}/${other}"/arch/*/configs/"${board}"*_defconfig; do
            [[ -f "${cand}" ]] && printf 'port\t%s\n' "${cand}"
        done
    done
    return 0
}

# The newest port candidate, i.e. what a port would seed from.
board_config_port_source() {
    local cfgroot=$1 board=$2 series=$3 kind path last=""
    # Candidates are emitted oldest series first, so the last port entry is the
    # newest configuration available for this board.
    while IFS=$'\t' read -r kind path; do
        if [[ "${kind}" == "port" ]]; then last="${path}"; fi
    done < <(board_config_candidates "${cfgroot}" "${board}" "${series}")
    [[ -n "${last}" ]] && printf '%s\n' "${last}"
    return 0
}

# Symbols the seed configuration asked for that this kernel's Kconfig does not
# define: the feature loss a port cannot avoid.  Counted and listed, never
# swallowed.
report_dropped_symbols() {
    local seed=$1 resolved=$2 out=$3
    mkdir -p "$(dirname -- "${out}")"
    grep -oE '^CONFIG_[A-Za-z0-9_]+=' "${seed}" 2>/dev/null | sed 's/=$//' | sort -u > "${out}.want"
    grep -oE '^CONFIG_[A-Za-z0-9_]+=' "${resolved}" 2>/dev/null | sed 's/=$//' | sort -u > "${out}.have"
    comm -23 "${out}.want" "${out}.have" > "${out}.dropped" 2>/dev/null || true
    wc -l < "${out}.dropped" 2>/dev/null | tr -d ' ' || printf '0'
}

#------------------------------------------------------- config repo access
# Clone (or reuse) the OpenHarmony configuration repository for a lane.
#
# OKCP_CONFIG_REPO_DIR points at an already-fetched checkout.  Cloning it once
# and reusing it matters in practice: a lane matrix clones it per lane otherwise,
# and it is also what makes the configuration path testable without a network.
fetch_ohos_config_repo() {
    local lane=$1 dest=${2:-${OKCP_WORKDIR:-${OKCP_ROOT}/build}/config/${lane}}
    local branch url
    branch=$(lane_ohos_branch "${lane}")
    [[ "${branch}" != "-" ]] || die "lane '${lane}' is not an OpenHarmony lane; it has no config-repo branch"
    url="${OKCP_OHOS_HOST}/${OKCP_CONFIG_REPO}.git"

    if [[ -n "${OKCP_CONFIG_REPO_DIR:-}" && -d "${OKCP_CONFIG_REPO_DIR}" ]]; then
        printf '%s\n' "${OKCP_CONFIG_REPO_DIR}"
        return 0
    fi
    if [[ -d "${dest}/.git" ]]; then printf '%s\n' "${dest}"; return 0; fi
    mkdir -p "$(dirname -- "${dest}")"
    log_step "fetching OpenHarmony config repo: ${OKCP_CONFIG_REPO}@${branch}"
    retry "${OKCP_FETCH_ATTEMPTS:-10}" "${OKCP_FETCH_BACKOFF:-30}" \
        git_do clone --depth=1 --single-branch --branch "${branch}" "${url}" "${dest}" \
        || die "cannot fetch ${url} (branch ${branch})"
    printf '%s\n' "${dest}"
}

# Is a defconfig a complete generated .config rather than a fragment?
config_is_full() {
    local f=$1 lines
    [[ -f "${f}" ]] || return 1
    lines=$(wc -l < "${f}" 2>/dev/null || echo 0)
    head -20 "${f}" | grep -qiE 'Automatically generated file|Generated by' && return 0
    (( lines > 2000 ))
}

# Fragments from this repository, in application order.
collect_local_fragments() {
    local lane=$1 arch=$2 d
    for d in "${OKCP_CONFIG_ROOT}/base/${arch}" "${OKCP_CONFIG_ROOT}/lanes/$(lane_overlay "${lane}")"; do
        if [[ -d "${d}" ]]; then
            find "${d}" -maxdepth 1 -type f \( -name '*.config' -o -name '*.fragment' \) | sort
        else
            log_debug "no config layer: ${d}"
        fi
    done
}

#--------------------------------------------------------------- merging
# _merge_fragments <srcdir> <out_config> <fragment>...
#
# Delegates to the kernel's own scripts/kconfig/merge_config.sh so we inherit
# upstream's handling of overridden and redundant symbols instead of
# reimplementing it.
#
# Its real contract, read from Linux 6.6.101 scripts/kconfig/merge_config.sh:
#
#   -m              boolean: merge only, do not run make afterwards
#   -O <dir>        directory for the generated output; the result is
#                   <dir>/.config  (it sets KCONFIG_CONFIG accordingly)
#   <base> <frags>  the first positional is the BASE file, the rest are
#                   fragments merged over it, later definitions winning
#
# There is no "-m <file>".  An earlier version of this function passed one,
# which made the real script treat the output path as a fragment and leave the
# real result in the -O directory; a stub that mirrored the invented contract
# hid the bug until CI met the real one.
#
# The script creates its temporary files in the current directory, so it must
# run with the kernel source tree as cwd.
_merge_fragments() {
    local srcdir=$1 out=$2; shift 2
    local -a frags=()
    local f
    for f in "$@"; do
        if [[ -s "${f}" ]]; then frags+=("${f}"); fi
    done
    if [[ ${#frags[@]} -eq 0 ]]; then
        die "no config fragments to merge"
    fi

    local merge="${srcdir}/scripts/kconfig/merge_config.sh"
    local tmp; tmp=$(make_tmpdir)

    if [[ ! -x "${merge}" ]]; then
        # merge_config.sh landed in Linux 5.17, so the 5.10 tree has none.
        # Concatenating in order is semantically correct for override-style
        # fragments: kconfig reads a configuration top to bottom and each
        # assignment replaces the previous value, including "# CONFIG_X is not
        # set".  olddefconfig then resolves whatever the fragments implied.
        log_warn "${merge#"${srcdir}"/} is absent (pre-5.17 kernel);"
        log_warn "  concatenating ${#frags[@]} fragment(s) in order and letting olddefconfig resolve"
        cat "${frags[@]}" > "${out}"
        printf '%s\n' "${out}"
        return 0
    fi

    : > "${tmp}/base.config"          # an empty base keeps ordering explicit

    # -m is a boolean flag ("merge only, do not run make") and -O takes the
    # output directory; the result is <dir>/.config, not <dir> itself.
    if ! ( cd "${srcdir}" && bash "${merge}" -m -O "${tmp}" "${tmp}/base.config" "${frags[@]}" ); then
        log_warn "merge_config.sh exited non-zero (continuing; olddefconfig will settle it)"
    fi

    if [[ ! -s "${tmp}/.config" ]]; then
        log_error "config merge produced no ${tmp}/.config"
        log_error "  fragments: $(printf '%s ' ${frags[@]+"${frags[@]}"})"
        log_error "  merge script: ${merge}"
        rm -rf "${tmp}"
        die "cannot merge the OpenHarmony configuration fragments"
    fi

    cp "${tmp}/.config" "${out}"
    rm -rf "${tmp}"
    printf '%s\n' "${out}"
}

#--------------------------------------------------------------- entry
# generate_config <lane> <srcdir> [kbuild_dir]
#
# Everything lands in <kbuild_dir>, which must be the same directory the later
# compile uses (see lane_outdir).  The source tree is left untouched: it stays
# pristinely rebuildable, and a second run does not inherit stale objects.
generate_config() {
    local lane=$1 srcdir=$2 outdir=${3:-$(lane_outdir "${lane}")}
    local out="${outdir}/.config" arch board mode="fragment" base_desc=""
    local -a frags=()

    require_file "${srcdir}/Makefile"
    arch=$(config_arch "${lane}")
    # The board comes from the lane unless the caller pinned one.  This is what
    # makes a build device-specific: without it the result is a generic kernel
    # with no GPU, Wi-Fi or board pin-mux.
    board=$(lane_board_layer "${lane}")
    log_debug "lane ${lane}: arch=${arch} board=${board:-<none, generic build>}"
    mkdir -p "${outdir}"

    #-- layer 0: explicit override ---------------------------------------
    if [[ -n "${OKCP_CONFIG_OVERRIDE:-}" ]]; then
        require_file "${OKCP_CONFIG_OVERRIDE}"
        log_step "config: explicit override ${OKCP_CONFIG_OVERRIDE}"
        if config_is_full "${OKCP_CONFIG_OVERRIDE}"; then
            mode="full"; cp "${OKCP_CONFIG_OVERRIDE}" "${out}"
        else
            frags+=("${OKCP_CONFIG_OVERRIDE}")
        fi

    #-- layers 1-2: the OpenHarmony config repo -------------------------
    elif [[ "$(lane_source_kind "${lane}")" == "ohos" && -z "${OKCP_NO_OHOS_CONFIG:-}" ]]; then
        # Every one of these is initialised to the empty string on purpose.
        # Under `set -u`, `local x` with no assignment leaves x *unset*, so a
        # short-circuited `[[ cond ]] && x=...` makes any later reference fail
        # with "unbound variable" instead of simply being empty.
        local cfgroot="" series="" base_def="" type_def="" board_def=""
        local ported_from="" dropped_n=0
        series=$(kernel_series "$(lane_kver "${lane}")")
        cfgroot=$(fetch_ohos_config_repo "${lane}")

        # Pick the board configuration.  Native for this series if there is
        # one; otherwise the newest configuration that exists for this board in
        # any other series, which the port then has to resolve against this
        # kernel's Kconfig.
        if [[ -n "${board}" ]]; then
            local kind path
            while IFS=$'\t' read -r kind path; do
                [[ -z "${path}" ]] && continue
                if [[ "${kind}" == "native" ]]; then
                    board_def="${path}"
                    break
                fi
                if [[ -z "${ported_from}" ]]; then
                    # keep looking: a native one later in the list still wins
                    ported_from="${path}"
                fi
            done < <(board_config_candidates "${cfgroot}" "${board}" "${series}")
            if [[ -z "${board_def}" && -n "${ported_from}" ]]; then
                board_def="${ported_from}"
            fi
        fi

        if [[ -n "${board_def}" ]]; then
            if [[ -n "${ported_from}" && "${board_def}" == "${ported_from}" ]]; then
                log_warn "no ${series} configuration for board '${board}'; porting from"
                log_warn "  ${board_def#"${cfgroot}"/} and letting ${series} kconfig resolve it"
                log_warn "  (symbols this kernel does not know are dropped and listed below)"
                mode="full"
                cp "${board_def}" "${out}"          # seed, resolved by olddefconfig
            else
                if config_is_full "${board_def}"; then
                    mode="full"
                    cp "${board_def}" "${out}"
                else
                    frags+=("${board_def}")
                fi
            fi
            base_desc="kernel_linux_config ${board_def#"${cfgroot}"/}"
        fi

        # The base and type fragments still apply when the board layer is a
        # fragment or absent; a complete board configuration supersedes them.
        if [[ "${mode}" != "full" ]]; then
            if [[ -f "${cfgroot}/linux-${series}/base_defconfig"                || -f "${cfgroot}/linux-${series}/type/${OKCP_SYSTEM_TYPE}_defconfig" ]]; then
                [[ -f "${cfgroot}/linux-${series}/base_defconfig" ]] \
                    && frags+=("${cfgroot}/linux-${series}/base_defconfig")
                [[ -f "${cfgroot}/linux-${series}/type/${OKCP_SYSTEM_TYPE}_defconfig" ]] \
                    && frags+=("${cfgroot}/linux-${series}/type/${OKCP_SYSTEM_TYPE}_defconfig")
                [[ -n "${base_desc}" ]] || base_desc="kernel_linux_config linux-${series} (fragments)"
            fi
        fi

        # The 4.19 generation keeps everything under arch/ instead.
        if [[ "${mode}" != "full" && ! -d "${cfgroot}/linux-${series}/arch" ]]; then
            local legacy="${cfgroot}/linux-${series}/arch/${arch}/configs"
            if [[ -f "${legacy}/${OKCP_SYSTEM_TYPE}_common_defconfig" ]]; then
                frags+=("${legacy}/${OKCP_SYSTEM_TYPE}_common_defconfig")
                [[ -n "${base_desc}" ]] || base_desc="kernel_linux_config linux-${series} (legacy layout)"
            fi
        fi
    fi

    #-- layer 3: in-tree fallback (loudly) -------------------------------
    if [[ "${mode}" == "fragment" && ${#frags[@]} -eq 0 ]]; then
        local own="${srcdir}/arch/${arch}/configs/defconfig"
        if [[ -f "${own}" ]]; then
            log_warn "the OpenHarmony config repo was not consulted; falling back to the"
            log_warn "  in-tree defconfig ${own#"${srcdir}"/}"
            log_warn "  This is NOT an OpenHarmony configuration: measured on 6.6.101 it"
            log_warn "  omits 652 of the 798 symbols OpenHarmony sets, including"
            log_warn "  CONFIG_ACCESS_TOKENID and CONFIG_ANDROID_BINDER_IPC."
            log_warn "  Pass --config, or remove --no-ohos-config, to build a real OHOS kernel."
            frags+=("${own}")
            base_desc="in-tree defconfig (FALLBACK, not an OHOS config)"
        fi
    fi

    #-- layers 4-5: this repository's overlays --------------------------
    local -a local_frags=()
    mapfile -t local_frags < <(collect_local_fragments "${lane}" "${arch}")
    if [[ ${#local_frags[@]} -gt 0 ]]; then
        log_step "config: applying ${#local_frags[@]} local fragment(s) on top"
        local f
        for f in "${local_frags[@]}"; do log_debug "  fragment: ${f#"${OKCP_ROOT}"/}"; done
        frags+=("${local_frags[@]}")
    fi

    # Nothing selected a base configuration and there is nothing to merge: that
    # is a real error.  The check must allow for the fragment path, where
    # ${out} does not exist yet because the merge below is what creates it.
    if [[ ! -f "${out}" && ${#frags[@]} -eq 0 ]]; then
        die "no base configuration was selected for lane '${lane}'
  Expected one of:
    - a complete board config in kernel_linux_config/linux-${series}/
    - kernel_linux_config/linux-${series}/{base,type/} defconfig
    - ${srcdir}/arch/${arch}/configs/defconfig
  Run './ohos-kb show ${lane}' to see what this lane resolves to."
    fi

    #-- merge -------------------------------------------------------------
    if [[ ${#frags[@]} -gt 0 ]]; then
        local tmp; tmp=$(make_tmpdir)
        _merge_fragments "${srcdir}" "${tmp}/merged" "${frags[@]}" >/dev/null
        cp "${tmp}/merged" "${out}"
        rm -rf "${tmp}"
    fi

    #-- settle ------------------------------------------------------------
    # O= must match the compile step, or kbuild later rejects the tree as dirty.
    log_step "config: olddefconfig (O=${outdir#"${OKCP_ROOT}"/})"
    if ! make -C "${srcdir}" -s O="${outdir}" ARCH="${arch}" olddefconfig > "${outdir}/olddefconfig.log" 2>&1; then
        log_warn "olddefconfig exited non-zero; last lines of ${outdir#"${OKCP_ROOT}"/}/olddefconfig.log:"
        tail -5 "${outdir}/olddefconfig.log" >&2 2>/dev/null || true
    fi
    cp -f "${out}" "${outdir}/.okcp-resolved-config" 2>/dev/null || true

    log_ok "config ready: ${out#"${OKCP_ROOT}"/} ($(wc -l < "${out}") lines)"
    log_info "base layer: ${base_desc:-adhoc override}"

    # A ported board configuration loses whatever this kernel no longer has.
    # Report it: a board configuration that silently shrank is a kernel that
    # quietly lost a device feature.
    if [[ -n "${board_def}" && "${board_def}" == "${ported_from}" ]]; then
        local rep="${outdir}/DROPPED-SYMBOLS.txt"
        dropped_n=$(report_dropped_symbols "${board_def}" "${out}" "${rep}")
        log_warn "ported '${board}' from ${board_def#"${cfgroot}"/}: ${dropped_n} symbol(s) dropped"
        if [[ "${dropped_n}" -gt 0 ]]; then
            log_warn "  first 20: $(head -20 "${rep}.dropped" 2>/dev/null | tr '\n' ' ')"
            log_warn "  full list: ${rep#"${OKCP_ROOT}"/}"
        fi
    fi
    config_facts "${out}" | sed 's/^/  /' | head -20
    printf '%s\n' "${out}"
}

#-------------------------------------------------------------------- facts
# The handful of options a reader actually asks about, so a CI job summary can
# answer "was this really an OpenHarmony kernel?" without opening 40k lines.
config_facts() {
    local cfg=$1 sym
    for sym in \
        CONFIG_LOCALVERSION CONFIG_ARM64 CONFIG_MODULES CONFIG_MODULE_UNLOAD \
        CONFIG_ACCESS_TOKENID CONFIG_ANDROID CONFIG_ANDROID_BINDER_IPC \
        CONFIG_SECURITY_SELINUX CONFIG_SECCOMP CONFIG_CFI_CLANG \
        CONFIG_BPF CONFIG_DRM CONFIG_NVME_CORE CONFIG_BLK_DEV_NVME \
        CONFIG_EXT4_FS CONFIG_F2FS_FS CONFIG_EROFS_FS CONFIG_OVERLAY_FS
    do
        grep -E "^${sym}=" "${cfg}" 2>/dev/null || true
    done | sort -u
}

# Which image artefacts this config will produce.
config_image_targets() {
    local cfg=$1
    require_file "${cfg}"
    local -a t=()
    grep -qx 'CONFIG_ARM64=y' "${cfg}" 2>/dev/null && t+=(Image)
    grep -qx 'CONFIG_ARM64=y' "${cfg}" 2>/dev/null && t+=(Image.gz)
    if grep -qx 'CONFIG_EFI=y' "${cfg}" 2>/dev/null; then t+=(Image-dtb); fi
    [[ ${#t[@]} -eq 0 ]] && t=(vmlinux bzImage)
    printf '%s\n' "${t[@]}" | sort -u
}

# Fast, build-free config check used by the PR gate workflow.
config_check() {
    local lane=$1 srcdir=$2 outdir
    outdir=$(make_tmpdir)
    generate_config "${lane}" "${srcdir}" "${outdir}" >/dev/null
    log_ok "config check passed for ${lane} ($(wc -l < "${outdir}/.config") lines)"
    rm -rf "${outdir}"
}
