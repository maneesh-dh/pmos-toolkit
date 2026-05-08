#!/usr/bin/env bash
# lint-stack-libraries.sh
#
# Verify each _shared/stacks/<stack>.md file contains the four required
# H2 sections that /plan v2 consumes.
#
# Required sections (all four must be present, exact H2 text):
#   ## Prereq Commands
#   ## Lint/Test Commands
#   ## API Smoke Patterns
#   ## Common Fixture Patterns
#
# Stacks list is hardcoded; adding a new stack requires updating this list
# in the same PR per skills/_shared/stacks/README.md "Maintenance Policy".
#
# Exit codes:
#   0 — all stack files have all required sections
#   1 — drift detected (missing file or missing section)
#   2 — script invocation error

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLUGIN_ROOT="$( cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
STACKS_DIR="${PLUGIN_ROOT}/skills/_shared/stacks"

STACKS=(npm pnpm yarn-classic yarn-berry bun python rails go static)
REQUIRED_SECTIONS=(
    "## Prereq Commands"
    "## Lint/Test Commands"
    "## API Smoke Patterns"
    "## Common Fixture Patterns"
)

if [[ ! -d "$STACKS_DIR" ]]; then
    echo "FAIL: stacks directory not found at $STACKS_DIR" >&2
    exit 1
fi

failures=0

for stack in "${STACKS[@]}"; do
    file="${STACKS_DIR}/${stack}.md"
    if [[ ! -f "$file" ]]; then
        echo "DRIFT: ${stack} — file missing at ${file}"
        failures=$((failures + 1))
        continue
    fi
    stack_ok=1
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -qF -- "$section" "$file"; then
            echo "DRIFT: ${stack} missing section: ${section}"
            stack_ok=0
            failures=$((failures + 1))
        fi
    done
    if [[ $stack_ok -eq 1 ]]; then
        echo "OK:    ${stack}"
    fi
done

if [[ $failures -gt 0 ]]; then
    echo
    echo "FAIL: ${failures} drift(s) detected across $(echo "${STACKS[@]}" | wc -w | tr -d ' ') stacks." >&2
    exit 1
fi

echo
echo "PASS: all $(echo "${STACKS[@]}" | wc -w | tr -d ' ') stack files have required sections."
exit 0
