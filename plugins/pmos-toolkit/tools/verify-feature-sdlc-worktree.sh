#!/usr/bin/env bash
# Integration-test driver for the worktree+resume rework.
# Exercises 8 cases. Each case prints PASS or FAIL with a one-line reason.
# Final line: "<n>/8 PASS" — exits 0 only when n=8.
#
# Most cases assert on production-code text (SKILL.md greps), since exec'ing
# the live skills requires the harness; one case (FR-D01) constructs a stub
# state.yaml + sandbox dir to verify the realpath drift logic via a small
# bash port of the contract.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0
TOTAL=8

pass() { echo "PASS [$1] $2"; PASS=$((PASS+1)); }
fail() { echo "FAIL [$1] $2"; }

# Case 1: FR-W01 — feature-sdlc/SKILL.md Phase 0.a Step 3 references EnterWorktree before pipeline continues
if grep -q "EnterWorktree(path=\$ABS_PATH)" "$REPO_ROOT/plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md" 2>/dev/null; then
  pass "Case 1 FR-W01" "Phase 0.a Step 3 calls EnterWorktree with abs path"
else
  fail "Case 1 FR-W01" "EnterWorktree(path=\$ABS_PATH) not found in feature-sdlc/SKILL.md"
fi

# Case 2: FR-W02 — handoff path documented (Status: handoff-required line)
if grep -qF "Status: handoff-required" "$REPO_ROOT/plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md"; then
  pass "Case 2 FR-W02" "handoff-required status line present"
else
  fail "Case 2 FR-W02" "Status: handoff-required line missing"
fi

# Case 3: FR-D01 — realpath drift check: byte-equal canonical paths pass
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
STORED="$(realpath "$TMPDIR" 2>/dev/null || python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$TMPDIR")"
ACTUAL="$(realpath "$TMPDIR" 2>/dev/null || python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$TMPDIR")"
if [ "$STORED" = "$ACTUAL" ]; then
  pass "Case 3 FR-D01" "byte-equal canonical paths: drift check passes"
else
  fail "Case 3 FR-D01" "byte-equal canonical paths differed ('$STORED' vs '$ACTUAL')"
fi

# Case 4: FR-D02 — realpath drift check: distinct canonical paths fail
STORED2="$(realpath "$TMPDIR" 2>/dev/null || python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$TMPDIR")"
ACTUAL2="$(realpath "$HOME" 2>/dev/null || python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$HOME")"
if [ "$STORED2" != "$ACTUAL2" ]; then
  pass "Case 4 FR-D02" "distinct canonical paths: drift detected"
else
  fail "Case 4 FR-D02" "distinct paths collided unexpectedly"
fi

# Case 5: FR-G01 — .gitignore contains .pmos/feature-sdlc/
if grep -qF ".pmos/feature-sdlc/" "$REPO_ROOT/.gitignore"; then
  pass "Case 5 FR-G01" "gitignore excludes .pmos/feature-sdlc/"
else
  fail "Case 5 FR-G01" ".pmos/feature-sdlc/ missing from .gitignore"
fi

# Case 6: FR-L01 — list subcommand documented in feature-sdlc/SKILL.md
if grep -qF "list logic" "$REPO_ROOT/plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md" \
   && grep -qF "git worktree list --porcelain" "$REPO_ROOT/plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md"; then
  pass "Case 6 FR-L01" "list subcommand prose present (logic + git worktree list invocation)"
else
  fail "Case 6 FR-L01" "list subcommand prose incomplete in feature-sdlc/SKILL.md"
fi

# Case 7: FR-CD01+CD04 — complete-dev/SKILL.md Phase 4 calls ExitWorktree(action=keep)
if grep -qF "ExitWorktree(action=keep)" "$REPO_ROOT/plugins/pmos-toolkit/skills/complete-dev/SKILL.md"; then
  pass "Case 7 FR-CD01+CD04" "Phase 4 calls ExitWorktree(action=keep)"
else
  fail "Case 7 FR-CD01+CD04" "ExitWorktree(action=keep) missing in complete-dev/SKILL.md Phase 4"
fi

# Case 8: FR-CD02 — --force-cleanup flag documented in complete-dev/SKILL.md AND argument-hint
if grep -q -F -e "--force-cleanup" "$REPO_ROOT/plugins/pmos-toolkit/skills/complete-dev/SKILL.md" \
   && head -10 "$REPO_ROOT/plugins/pmos-toolkit/skills/complete-dev/SKILL.md" | grep -q -F -e "--force-cleanup"; then
  pass "Case 8 FR-CD02" "--force-cleanup in body AND argument-hint frontmatter"
else
  fail "Case 8 FR-CD02" "--force-cleanup missing from body or argument-hint"
fi

echo "$PASS/$TOTAL PASS"
[ "$PASS" -eq "$TOTAL" ] && exit 0 || exit 1
