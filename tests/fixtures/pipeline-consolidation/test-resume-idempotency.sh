#!/bin/bash
# T13 fixture: started_at write contract + resume idempotency.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md

# started_at on transition pending→in_progress
n=$(/usr/bin/grep -c "started_at" "$f")
test "$n" -ge 4

/usr/bin/grep -q "Phase status-transition write contract" "$f"
/usr/bin/grep -q "FR-57" "$f"
/usr/bin/grep -q "preserve the original timestamp" "$f"

# Atomic D31 write contract documented
/usr/bin/grep -q "rename(2)" "$f"
/usr/bin/grep -q "NFR-08" "$f"

echo OK
