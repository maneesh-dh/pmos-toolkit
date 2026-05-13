#!/usr/bin/env bash
# check-determinism.sh — run tools/run-audit.sh twice against the same scan root,
# strip ephemeral fields, and assert byte-identical output (FR-73, NFR-02).
# Exit 0 if diff is empty; exit 1 with the diff on stderr otherwise; 64 on usage error.
# Argv:    <scan-root>   (required)
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_AUDIT="$SKILL_DIR/tools/run-audit.sh"

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <scan-root>" >&2
  exit 64
fi
SCAN_ROOT="$1"
if [ ! -e "$SCAN_ROOT" ]; then
  echo "ERROR: scan root does not exist: $SCAN_ROOT" >&2
  exit 64
fi
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: check-determinism.sh requires jq." >&2
  exit 64
}
if [ ! -x "$RUN_AUDIT" ]; then
  echo "ERROR: run-audit.sh not executable at: $RUN_AUDIT" >&2
  exit 64
fi

TMPDIR_=$(mktemp -d)
trap 'rm -rf "$TMPDIR_"' EXIT

# Strip ephemeral time fields (start/end timestamps + wall-clock duration).
# Match the actual report shape emitted by run-audit.sh — see SKILL.md Phase 6.
STRIP='del(.run.started_at, .run.finished_at, .run.duration_s)'

# --no-adr suppresses ADR-write side effects so two consecutive runs against the
# same scan root produce byte-identical findings (FR-67 + FR-73). With ADR writes
# enabled, the second run sees the first run's ADRs on disk and increments NNNN,
# which is correct behavior but not a determinism violation.
bash "$RUN_AUDIT" audit --no-adr "$SCAN_ROOT" 2>/dev/null | jq "$STRIP" > "$TMPDIR_/a.json"
sleep 1
bash "$RUN_AUDIT" audit --no-adr "$SCAN_ROOT" 2>/dev/null | jq "$STRIP" > "$TMPDIR_/b.json"

if diff -q "$TMPDIR_/a.json" "$TMPDIR_/b.json" >/dev/null; then
  echo "OK: determinism check passed (2 runs against $SCAN_ROOT yielded byte-identical output)." >&2
  exit 0
else
  echo "FAIL: determinism check failed — diff follows:" >&2
  diff "$TMPDIR_/a.json" "$TMPDIR_/b.json" >&2 || true
  exit 1
fi
