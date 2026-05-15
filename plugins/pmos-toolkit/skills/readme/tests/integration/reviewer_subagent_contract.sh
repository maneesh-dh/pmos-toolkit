#!/usr/bin/env bash
# T4: 3-variant contract test for reviewer-subagent return validation (FR-11/FR-12).
#
# Variants:
#   A — valid reviewer return (both [J] PASS, ≥40-char quotes) → accepted.
#   B — sub-40-char quote on one finding                       → hard-fail.
#   C — missing check_id (set-equality violation)              → hard-fail.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SKILL_DIR="$REPO/plugins/pmos-toolkit/skills/readme"
FIXTURE="$SKILL_DIR/tests/fixtures/rubric/strong/01_hero-line.md"

# Quote the test reuses for variants A and C — guaranteed to be a verbatim
# substring of the fixture's line 3 (the hero line).
HERO_QUOTE="ripgrep is a line-oriented search tool for recursively searching the current directory for a regex pattern."

source "$SKILL_DIR/scripts/_reviewer_validate.sh"

# Variant A: valid → expect exit 0
JSON_A=$(cat <<JSON
[
  {"check_id":"hero-scope-matches-surface","verdict":"pass","fix_note":"","quote":"$HERO_QUOTE"},
  {"check_id":"primary-index-by-jtbd","verdict":"pass","fix_note":"","quote":"$HERO_QUOTE"}
]
JSON
)
if ! readme::reviewer_validate "$JSON_A" "$FIXTURE" 2>/tmp/t4-stderr-a; then
  echo "FAIL: variant A (valid) was rejected"; cat /tmp/t4-stderr-a; exit 1
fi
echo "PASS: variant A (valid)"

# Variant B: sub-40 quote → expect exit 1 + specific message
JSON_B=$(cat <<JSON
[
  {"check_id":"hero-scope-matches-surface","verdict":"fail","fix_note":"tighten hero","quote":"too short"},
  {"check_id":"primary-index-by-jtbd","verdict":"pass","fix_note":"","quote":"$HERO_QUOTE"}
]
JSON
)
if readme::reviewer_validate "$JSON_B" "$FIXTURE" 2>/tmp/t4-stderr-b; then
  echo "FAIL: variant B (sub-40 quote) was accepted"; exit 1
fi
grep -q "reviewer returned quote shorter than 40 chars" /tmp/t4-stderr-b \
  || { echo "FAIL: variant B stderr missing expected message"; cat /tmp/t4-stderr-b; exit 1; }
echo "PASS: variant B (sub-40 hard-fail)"

# Variant C: missing check_id → expect exit 1 + set-equality message
JSON_C=$(cat <<JSON
[
  {"check_id":"hero-scope-matches-surface","verdict":"pass","fix_note":"","quote":"$HERO_QUOTE"}
]
JSON
)
if readme::reviewer_validate "$JSON_C" "$FIXTURE" 2>/tmp/t4-stderr-c; then
  echo "FAIL: variant C (missing check_id) was accepted"; exit 1
fi
grep -q "reviewer returned check_ids that do not match rubric.yaml" /tmp/t4-stderr-c \
  || { echo "FAIL: variant C stderr missing set-equality message"; cat /tmp/t4-stderr-c; exit 1; }
echo "PASS: variant C (missing check_id hard-fail)"

rm -f /tmp/t4-stderr-a /tmp/t4-stderr-b /tmp/t4-stderr-c
echo "ALL T4 VARIANTS PASSED"
