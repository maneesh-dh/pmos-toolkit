#!/usr/bin/env bash
# lint-pipeline-setup-inline.sh
#
# Verify that the canonical Phase 0 inline block (between
# `<!-- pipeline-setup-block:start -->` and `<!-- pipeline-setup-block:end -->`)
# is present and identical across all pipeline skills.
#
# Canonical source: skills/_shared/pipeline-setup.md (Section 0)
# Required in:      skills/{requirements,spec,plan,execute,verify,wireframes,prototype}/SKILL.md
#
# Exit codes:
#   0 — all skills match canonical
#   1 — drift detected, missing markers, or canonical not found
#   2 — script invocation error (bad arguments, missing tools)

set -euo pipefail

# Resolve script's plugin root (parent of tools/)
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLUGIN_ROOT="$( cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd )"

CANONICAL_FILE="${PLUGIN_ROOT}/skills/_shared/pipeline-setup.md"
PIPELINE_SKILLS=(requirements spec plan execute verify wireframes prototype)

START_MARKER='<!-- pipeline-setup-block:start -->'
END_MARKER='<!-- pipeline-setup-block:end -->'

# Extract content between markers (exclusive of marker lines).
# Args: $1 = file path
# Stdout: extracted block content (may be empty)
# Exit: 0 if both markers found, 1 otherwise
extract_block() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 == start { in_block = 1; found_start = 1; next }
        $0 == end   { in_block = 0; found_end = 1; next }
        in_block    { print }
        END         { exit (found_start && found_end) ? 0 : 1 }
    ' "$file"
}

# --- Step 1: extract canonical block ---
if [[ ! -f "$CANONICAL_FILE" ]]; then
    echo "ERROR: canonical file not found: $CANONICAL_FILE" >&2
    exit 2
fi

CANONICAL=$(extract_block "$CANONICAL_FILE") || {
    echo "ERROR: canonical file is missing pipeline-setup-block markers." >&2
    echo "       expected both <!-- pipeline-setup-block:start --> and <!-- pipeline-setup-block:end --> in:" >&2
    echo "       $CANONICAL_FILE" >&2
    exit 2
}

if [[ -z "${CANONICAL//[$' \t\n']/}" ]]; then
    echo "ERROR: canonical block is empty in $CANONICAL_FILE" >&2
    exit 2
fi

# --- Step 2: diff each pipeline SKILL.md against canonical ---
DRIFT_COUNT=0
MISSING_COUNT=0

for skill in "${PIPELINE_SKILLS[@]}"; do
    skill_file="${PLUGIN_ROOT}/skills/${skill}/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
        echo "MISSING: ${skill}/SKILL.md not found at ${skill_file}"
        MISSING_COUNT=$((MISSING_COUNT + 1))
        continue
    fi

    if ! actual=$(extract_block "$skill_file"); then
        echo "MISSING-BLOCK: ${skill}/SKILL.md is missing pipeline-setup-block markers."
        echo "  Expected both ${START_MARKER} and ${END_MARKER} in: ${skill_file}"
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
        continue
    fi

    if [[ "$actual" == "$CANONICAL" ]]; then
        echo "OK:      ${skill}/SKILL.md"
    else
        echo "DRIFT:   ${skill}/SKILL.md"
        echo "  --- canonical (from ${CANONICAL_FILE#${PLUGIN_ROOT}/}) ---"
        echo "  +++ ${skill}/SKILL.md +++"
        diff <(printf '%s\n' "$CANONICAL") <(printf '%s\n' "$actual") \
            | sed 's/^/  /' || true
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
done

# --- Step 3: summarize ---
echo
TOTAL_FAIL=$((DRIFT_COUNT + MISSING_COUNT))
if [[ $TOTAL_FAIL -eq 0 ]]; then
    echo "PASS: all ${#PIPELINE_SKILLS[@]} pipeline skills match canonical."
    exit 0
else
    echo "FAIL: ${TOTAL_FAIL} skill(s) failed (drift=${DRIFT_COUNT}, missing=${MISSING_COUNT})."
    exit 1
fi
