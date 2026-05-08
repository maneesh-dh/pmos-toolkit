#!/usr/bin/env bash
set -e
P=tests/fixtures/repos/python/docs/pmos/features/2026-05-09_fixture-bugfix/03_plan.md
test -f "$P" || { echo "FAIL: plan not produced at $P"; exit 1; }
task_count=$(grep -c '^### T[0-9]' "$P")
[[ $task_count -eq 1 ]] || { echo "FAIL: expected 1 task, got $task_count"; exit 1; }
! grep -q '^## Decision Log$' "$P" || { echo "FAIL: T1 plan should skip Decision-Log floor"; exit 1; }
grep -qiE 'done-when walkthrough' "$P" || { echo "FAIL: missing Done-when walkthrough"; exit 1; }
! grep -qi 'alembic' "$P" || { echo "FAIL: stack=python detected but alembic still leaked (should NOT appear in T1 reduced TN)"; exit 1; }
echo PASS
