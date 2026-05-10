#!/bin/bash
# W3 fixture: /spec gains Phase 6.5 folded simulate-spec — --skip-folded-sim-spec,
# FR-66, per-finding commit pattern, substrate delegation, failure capture.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/spec/SKILL.md

/usr/bin/grep -q '^## Phase 6\.5: Folded simulate-spec' "$f"
n=$(/usr/bin/grep -c -- 'skip-folded-sim-spec' "$f")
test "$n" -ge 2
/usr/bin/grep -q 'auto-apply simulate-spec patch P' "$f"
/usr/bin/grep -q 'FR-66' "$f"
/usr/bin/grep -q 'folded_phase_failures' "$f"
/usr/bin/grep -q '_shared/sim-spec-heuristics.md' "$f"

echo OK
