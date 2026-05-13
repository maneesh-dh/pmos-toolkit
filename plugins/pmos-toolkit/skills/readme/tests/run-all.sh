#!/usr/bin/env bash
# run-all.sh — single deterministic entry point for the /readme test suite.
#
# Runs:
#   1. Every substrate's --selftest under scripts/ (rubric, workspace-discovery,
#      commit-classifier, voice-diff).
#   2. Every integration script under tests/integration/.
#
# Exits 0 iff every test passes; exits 1 on the first failure (after letting
# subsequent tests run, so the user sees the full picture).
#
# Bash 3.2-safe. Total wall-clock target ≤ 30s.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HERE/../scripts"
INTEG_DIR="$HERE/integration"

passed=0
failed=0
failures=""

run_one() {
  local label="$1" cmd="$2"
  if eval "$cmd" >/tmp/readme-run-all-$$.log 2>&1; then
    printf '  OK   %s\n' "$label"
    passed=$((passed + 1))
  else
    rc=$?
    printf '  FAIL %s (rc=%d)\n' "$label" "$rc"
    sed -e 's/^/         /' /tmp/readme-run-all-$$.log
    failed=$((failed + 1))
    failures="$failures $label"
  fi
}
trap 'rm -f /tmp/readme-run-all-$$.log' EXIT

# --- Substrate self-tests ----------------------------------------------------
substrate_count=0
for s in rubric.sh workspace-discovery.sh commit-classifier.sh voice-diff.sh; do
  [ -f "$SCRIPTS_DIR/$s" ] || { echo "  SKIP $s (missing)"; continue; }
  run_one "scripts/$s --selftest" "bash '$SCRIPTS_DIR/$s' --selftest"
  substrate_count=$((substrate_count + 1))
done

# --- Integration suite -------------------------------------------------------
integ_count=0
if [ -d "$INTEG_DIR" ]; then
  for t in "$INTEG_DIR"/*.sh; do
    [ -f "$t" ] || continue
    run_one "integration/$(basename "$t")" "bash '$t'"
    integ_count=$((integ_count + 1))
  done
fi

total=$((passed + failed))
printf '\n[/readme] run-all: %d scripts + %d integration tests = %d passed\n' \
  "$substrate_count" "$integ_count" "$passed"

if [ "$failed" -gt 0 ]; then
  printf '[/readme] run-all: %d FAILED (of %d) —%s\n' "$failed" "$total" "$failures"
  exit 1
fi
exit 0
