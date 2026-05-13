#!/usr/bin/env bash
# audit_cluttered.sh — "good-but-cluttered" audit produces a bounded
# structural diff (≤20 lines of findings) per the spec §13.2 requirements-
# satisfaction signal.
#
# Uses tests/fixtures/rubric/targeted/badges-stale.md as the cluttered
# fixture (kept outside strong/ and slop/ to avoid contaminating rubric.sh's
# A2 agreement gate). Closes residual phase-2-r3: the badges-not-stale check
# fires on the `shields.io...cacheSeconds=-1` regex without polluting the
# selftest denominator.
#
# Bash 3.2-safe.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../scripts"
FIXTURE="$HERE/../fixtures/rubric/targeted/badges-stale.md"

tmp="$(mktemp -d -t readme-audit-cluttered.XXXXXX)"
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

[ -f "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

cp "$FIXTURE" "$tmp/README.md"

# Materialise CONTRIBUTING.md / LICENSE so links-resolve doesn't drown the
# structural-diff signal we're testing for.
: > "$tmp/CONTRIBUTING.md"
: > "$tmp/LICENSE"

bash "$SCRIPTS/rubric.sh" "$tmp/README.md" >"$tmp/findings.tsv" 2>&1 || true

# (1) badges-not-stale must fire on this fixture (phase-2-r3 evidence).
if ! grep -qE '^badges-not-stale[[:space:]]+FAIL' "$tmp/findings.tsv"; then
  echo "FAIL: badges-not-stale did not fire on the stale-cache fixture"
  cat "$tmp/findings.tsv"
  exit 1
fi

# (2) Structural diff bound: ≤20 lines of FAIL findings. A "good-but-
# cluttered" README should produce a small, surgical set of findings, not
# a wall of red.
fail_count=$(grep -c $'\tFAIL\t' "$tmp/findings.tsv" || true)
total_lines=$(wc -l < "$tmp/findings.tsv" | tr -d ' ')
if [ "${fail_count:-0}" -gt 20 ]; then
  echo "FAIL: cluttered audit produced ${fail_count} FAIL rows (>20 cap)"
  grep $'\tFAIL\t' "$tmp/findings.tsv"
  exit 1
fi

echo "PASS: audit_cluttered — ${fail_count} FAIL rows (<=20), badges-not-stale fires (phase-2-r3 closed); total findings TSV=${total_lines} lines"
exit 0
