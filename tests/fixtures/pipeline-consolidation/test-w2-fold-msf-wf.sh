#!/bin/bash
# W2 fixture: /wireframes Phase 6 folded contract — --skip-folded-msf-wf,
# FR-65 uncommitted, slug-distinct output (msf-wf-findings/<id>.md),
# per-finding commits, failure capture.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/wireframes/SKILL.md

/usr/bin/grep -q '^## Phase 6:' "$f"
n=$(/usr/bin/grep -c -- 'skip-folded-msf-wf' "$f")
test "$n" -ge 2
/usr/bin/grep -q 'msf-wf-findings/<wireframe-id>\.md' "$f"
/usr/bin/grep -q 'auto-apply msf-wf finding F' "$f"
/usr/bin/grep -q 'FR-65' "$f"
/usr/bin/grep -q 'folded_phase_failures' "$f"
/usr/bin/grep -q -- '--msf-auto-apply-threshold' "$f"

echo OK
