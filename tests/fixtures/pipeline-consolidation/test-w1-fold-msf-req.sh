#!/bin/bash
# W1 fixture: /requirements gains Phase 5.5 folded MSF-req with --skip-folded-msf
# escape, slug-distinct output, per-finding commit pattern, FR-64 uncommitted guard.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/requirements/SKILL.md

# 1. Phase 5.5 section present
/usr/bin/grep -q '^## Phase 5\.5: Folded MSF-req' "$f"

# 2. --skip-folded-msf flag handling (≥2: parser + reference)
n=$(/usr/bin/grep -c -- 'skip-folded-msf' "$f")
test "$n" -ge 2

# 3. Output slug is the new convention, not legacy
/usr/bin/grep -q 'msf-req-findings\.md' "$f"
! /usr/bin/grep -q 'NOT.*msf-findings\.md' "$f" || true  # legacy mention is allowed only as anti-pattern

# 4. Per-finding commit pattern documented
/usr/bin/grep -q 'auto-apply msf-req finding F' "$f"

# 5. FR-64 uncommitted guard documented
/usr/bin/grep -q 'FR-64' "$f"

# 6. Failure capture documented (FR-50/M1)
/usr/bin/grep -q 'folded_phase_failures' "$f"

# 7. msf-auto-apply-threshold flag documented
/usr/bin/grep -q -- '--msf-auto-apply-threshold' "$f"

# W4 dogfood: dogfood feature folder uses slug-distinct path
test -f docs/pmos/features/2026-05-10_pipeline-consolidation/msf-req-findings.md
! test -f docs/pmos/features/2026-05-10_pipeline-consolidation/msf-findings.md

echo OK
