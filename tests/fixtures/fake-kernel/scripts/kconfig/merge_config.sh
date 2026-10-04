#!/bin/bash
# Minimal stand-in for the kernel's merge_config.sh, good enough to test the
# call contract this project relies on:
#
#   merge_config.sh -O <outdir> -m <output> <fragment>...
#
# The merged result goes to <output> (the -m argument).  <outdir> receives
# only intermediate Kconfig override files.  A stub that confused the two
# would hide exactly the bug this fixture was written to catch.
outdir=""; output=""; frags=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O) outdir=$2; shift 2 ;;
        -m) output=$2; shift 2 ;;
        *)  frags+=("$1"); shift ;;
    esac
done
[[ -n "${output}" ]] || { echo "no -m output given" >&2; exit 1; }

# Later fragments override earlier ones.
tmp=$(mktemp)
for f in ${frags[@]+"${frags[@]}"}; do
    grep -E '^CONFIG_[A-Za-z0-9_]+=' "$f" 2>/dev/null >> "${tmp}" || true
done
awk -F= '/^CONFIG_/ { v[$1]=$0 } END { for (k in v) print v[k] }' "${tmp}" | sort > "${output}"
rm -f "${tmp}"

# -O is the directory for intermediate override files, not the result.
if [[ -n "${outdir}" ]]; then
    : > "${outdir}/.config"
fi
exit 0
