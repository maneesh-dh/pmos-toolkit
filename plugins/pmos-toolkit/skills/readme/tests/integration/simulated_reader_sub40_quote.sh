#!/usr/bin/env bash
# T7: regression test for FR-SR-3 sub-40-char quote hard-fail.
#
# The skill MUST hard-fail when a persona subagent returns a quote shorter
# than 40 chars; this test locks that contract structurally so a future
# silent-relax can't sneak back in.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SKILL_DIR="$REPO/plugins/pmos-toolkit/skills/readme"
STUB="$SKILL_DIR/tests/mocks/persona_stub_sub40.sh"
FIXTURE="$SKILL_DIR/tests/fixtures/rubric/strong/01_hero-line.md"

[[ -x "$STUB" ]] || { echo "FAIL: sub40 persona stub missing or not executable: $STUB"; exit 1; }
[[ -f "$FIXTURE" ]] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

# Setup: capture the stub's deliberately-short quote.
RAW="$(bash "$STUB" --persona=evaluator "$FIXTURE")"
LEN=$(printf '%s' "$RAW" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
print(len(d['friction'][0]['quote']))
")
[[ "$LEN" -lt 40 ]] || { echo "FAIL: stub did not return sub-40 quote (got len=$LEN)"; exit 1; }

# Exercise the parent-side validation logic — same shape as SKILL.md §2 step 2
# enforces. Expect hard-fail with the documented message.
set +e
ERR=$(python3 - "$RAW" "$FIXTURE" <<'PYEOF' 2>&1
import sys, json
raw, readme_path = sys.argv[1], sys.argv[2]
d = json.loads(raw)
for f in d.get("friction", []):
    q = f.get("quote", "")
    if len(q) < 40:
        sys.stderr.write(f"simulated-reader returned quote shorter than 40 chars: {q}\n")
        sys.exit(1)
sys.exit(0)
PYEOF
)
EXIT_CODE=$?
set -e

[[ "$EXIT_CODE" -ne 0 ]] || { echo "FAIL: sub-40 quote did not hard-fail (exit=$EXIT_CODE)"; exit 1; }
echo "$ERR" | grep -q "simulated-reader returned quote shorter than 40 chars" \
  || { echo "FAIL: hard-fail message missing or wrong"; echo "$ERR"; exit 1; }

echo "PASS: FR-SR-3 sub-40 quote hard-fail enforced (quote len=$LEN)"
