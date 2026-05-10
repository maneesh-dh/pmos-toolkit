#!/bin/bash
# W5 fixture (T9 + extensions for T10/T11):
# Asserts /feature-sdlc/SKILL.md no longer has the obsolete msf-req + simulate-spec
# gate sections; structural greps mirror the runtime AUTO-PICK count expectation
# (4 soft gates remaining: creativity, wireframes, prototype, retro).
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md

# T9: obsolete gates removed
test "$(/usr/bin/grep -c '^## Phase 4\.a:' "$f")" = 0
test "$(/usr/bin/grep -c '^## Phase 6:' "$f")" = 0

# T9: anti-pattern #4 mentions removal
/usr/bin/grep -q 'no longer have orchestrator gates' "$f"

# T9: auto-migration block for pre-2.34.0 state.yaml
/usr/bin/grep -q 'Auto-migration of pre-2.34.0 state files' "$f"

# 4 soft gate sections still present (creativity, wireframes, prototype + new retro from T10)
test "$(/usr/bin/grep -c '^## Phase 4\.b:' "$f")" = 1
test "$(/usr/bin/grep -c '^## Phase 4\.c:' "$f")" = 1
test "$(/usr/bin/grep -c '^## Phase 4\.d:' "$f")" = 1

echo OK
