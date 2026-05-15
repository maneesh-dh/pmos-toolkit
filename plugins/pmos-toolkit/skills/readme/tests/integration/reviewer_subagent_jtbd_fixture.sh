#!/usr/bin/env bash
# T8: reviewer-subagent stub-driven test against the JTBD-organized synthetic
# README. Locks the two-sided fixture guarantee (G2 / spec D6): a known-good
# JTBD-organized README passes both [J] checks through the parent-side
# validation pipeline.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SKILL_DIR="$REPO/plugins/pmos-toolkit/skills/readme"
FIXTURE="$SKILL_DIR/tests/fixtures/jtbd-organized-readme.md"
STUB="$SKILL_DIR/tests/mocks/reviewer_stub.sh"

[[ -f "$FIXTURE" ]] || { echo "FAIL: fixture missing at $FIXTURE"; exit 1; }
[[ -x "$STUB" ]] || { echo "FAIL: reviewer_stub.sh not executable"; exit 1; }

# Drive the stub against the JTBD fixture, then run the parent-side validator.
JSON="$(bash "$STUB" "$FIXTURE")"
source "$SKILL_DIR/scripts/_reviewer_validate.sh"
if ! readme::reviewer_validate "$JSON" "$FIXTURE" 2>/tmp/t8-stderr; then
  echo "FAIL: reviewer validation failed on JTBD fixture"
  cat /tmp/t8-stderr
  exit 1
fi

# Both [J] check_ids must come back verdict=pass (the stub's default shape).
printf '%s' "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ids = {f['check_id']: f['verdict'] for f in d}
assert ids.get('hero-scope-matches-surface') == 'pass', f\"hero-scope verdict: {ids.get('hero-scope-matches-surface')}\"
assert ids.get('primary-index-by-jtbd')      == 'pass', f\"primary-index verdict: {ids.get('primary-index-by-jtbd')}\"
print('PASS: both [J] checks PASS on JTBD fixture')
"

rm -f /tmp/t8-stderr
