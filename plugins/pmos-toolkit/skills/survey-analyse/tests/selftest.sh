#!/usr/bin/env bash
# selftest.sh — run every helper module's --selftest.
# Exit non-zero on any failure.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$HERE/.." && pwd)"
cd "$SKILL_ROOT/scripts"

PY="${PYTHON:-python3}"
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "selftest: $PY not found on PATH. Install python3 and retry." >&2
  exit 127
fi

failed=0
for mod in categorical multi_select likert nps ranking matrix numeric stats clean ingest schema pii; do
  if "$PY" -m "helpers.$mod" --selftest; then
    :
  else
    echo "selftest: helpers.$mod FAILED" >&2
    failed=$((failed + 1))
  fi
done

if [ "$failed" -eq 0 ]; then
  echo "selftest: all helpers passed"
  exit 0
fi
echo "selftest: $failed module(s) failed" >&2
exit 1
