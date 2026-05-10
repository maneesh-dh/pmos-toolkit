#!/bin/bash
# T12b fixture: /feature-sdlc Phase 11 + Resume re-emit folded-phase failures.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md

# Phase 11 read + emit
n=$(/usr/bin/grep -c "folded_phase_failures\|Folded-phase failures" "$f")
test "$n" -ge 3

# Phase 0.b resume re-emit subsection
/usr/bin/grep -q "Resume Status panel folded-phase failure re-emit" "$f"

# Spec FR refs cited
/usr/bin/grep -q "FR-29\|FR-52" "$f"

echo OK
