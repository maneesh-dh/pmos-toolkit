#!/usr/bin/env bash
set -e
P=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature/03_plan.md
R=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature/03_plan_review.md
test -f "$P" || { echo "FAIL: plan not produced"; exit 1; }
test -f "$R" || { echo "FAIL: review sidecar not produced"; exit 1; }
grep -q '^## Phase 1' "$P" || { echo "FAIL: phases not used"; exit 1; }
[[ $(grep -cE '^\*\*Depends on:\*\*' "$P") -gt 0 ]] || { echo "FAIL: no Depends on fields"; exit 1; }
[[ $(grep -cE '^\*\*Idempotent:\*\*' "$P") -gt 0 ]] || { echo "FAIL: no Idempotent fields"; exit 1; }
grep -q '^```mermaid' "$P" || { echo "FAIL: no mermaid diagram"; exit 1; }
! grep -qE 'curl.*json\.tool' "$P" || { echo "FAIL: stack=node but python smoke leaked"; exit 1; }
! grep -qi 'alembic' "$P" || { echo "FAIL: alembic leaked"; exit 1; }
for wf in 01_dashboard.html 02_settings.html; do
  if ! grep -qF "wireframes/$wf" "$P"; then
    grep -qE '^## Wireframes Out of Scope' "$P" && grep -qF "$wf" "$P" || { echo "FAIL: wireframe $wf neither cited nor in Out-of-Scope"; exit 1; }
  fi
done
echo PASS
