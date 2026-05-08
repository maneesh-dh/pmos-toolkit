#!/usr/bin/env bash
# lint-js-stack-preambles.sh
#
# Diff the `## Common Preamble` region across the 5 JS-family stack files.
# The preamble must be byte-equivalent in every file; npm.md is canonical.
# Drift here means a maintainer edited one file but not the others — caught
# at PR time per skills/_shared/stacks/README.md "Maintenance Policy".
#
# Exit codes:
#   0 — all 5 preambles match canonical
#   1 — drift detected (one or more files differ)
#   2 — script invocation error

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLUGIN_ROOT="$( cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
STACKS_DIR="${PLUGIN_ROOT}/skills/_shared/stacks"

JS_STACKS=(npm pnpm yarn-classic yarn-berry bun)
CANONICAL=npm

extract_preamble() {
    awk '
        /^## Common Preamble/ { in_block = 1; next }
        /^## /                { in_block = 0 }
        in_block              { print }
    ' "$1"
}

canonical_file="${STACKS_DIR}/${CANONICAL}.md"
if [[ ! -f "$canonical_file" ]]; then
    echo "FAIL: canonical file missing: $canonical_file" >&2
    exit 1
fi

canonical_tmp=$(mktemp)
trap 'rm -f "$canonical_tmp" "${other_tmp:-}"' EXIT
extract_preamble "$canonical_file" > "$canonical_tmp"

if [[ ! -s "$canonical_tmp" ]]; then
    echo "FAIL: canonical preamble empty in ${CANONICAL}.md" >&2
    exit 1
fi

failures=0

for stack in "${JS_STACKS[@]}"; do
    if [[ "$stack" == "$CANONICAL" ]]; then
        echo "OK:    ${stack} (canonical)"
        continue
    fi
    other_file="${STACKS_DIR}/${stack}.md"
    if [[ ! -f "$other_file" ]]; then
        echo "DRIFT: ${stack} — file missing"
        failures=$((failures + 1))
        continue
    fi
    other_tmp=$(mktemp)
    extract_preamble "$other_file" > "$other_tmp"
    if diff -q "$canonical_tmp" "$other_tmp" > /dev/null; then
        echo "OK:    ${stack}"
    else
        echo "DRIFT: ${stack} preamble differs from ${CANONICAL}.md:"
        diff "$canonical_tmp" "$other_tmp" || true
        failures=$((failures + 1))
    fi
    rm -f "$other_tmp"
    other_tmp=""
done

if [[ $failures -gt 0 ]]; then
    echo
    echo "FAIL: ${failures} JS-stack preamble drift(s)." >&2
    exit 1
fi

echo
echo "PASS: all ${#JS_STACKS[@]} JS-stack preambles match canonical (${CANONICAL}.md)."
exit 0
