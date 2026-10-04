#!/bin/bash
# OFFLINE FALLBACK ONLY.
#
# tests/run-tests.sh replaces this with the real
# scripts/kconfig/merge_config.sh from the OpenHarmony kernel tree whenever
# gitcode is reachable, because the whole point of the end-to-end config test
# is to exercise the genuine tool's contract:
#
#   merge_config.sh -m -O <dir> <base> <fragment>...
#     -m      boolean: merge only, do not run make
#     -O dir  output directory; the result is <dir>/.config
#     $1      the base file, remaining arguments are fragments
#
# Getting this contract wrong is exactly the bug the end-to-end test exists to
# catch, so a stub that merely approximated it would defeat the exercise.
set -e
RUNMAKE=true; OUTPUT=.
while true; do
    case "$1" in
        -m) RUNMAKE=false; shift; continue ;;
        -O) OUTPUT=$2; shift 2; continue ;;
        -h) echo "usage: $0 [-m] [-O dir] [base] [fragments...]"; exit 0 ;;
        *) break ;;
    esac
done
KCONFIG_CONFIG="${OUTPUT}/.config"
[ "$OUTPUT" = "." ] && KCONFIG_CONFIG=".config"

INITFILE=$1; shift
[ -r "$INITFILE" ] || touch "$INITFILE"

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cp "$INITFILE" "$TMP"
for f in "$@"; do
    [ -r "$f" ] || { echo "The merge file '$f' does not exist.  Exit." >&2; exit 1; }
    cat "$f" >> "$TMP"
done
# Later definitions win.
awk -F= '/^CONFIG_/ { v[$1]=$0 } END { for (k in v) print v[k] }' "$TMP" | sort > "${KCONFIG_CONFIG}"
exit 0
