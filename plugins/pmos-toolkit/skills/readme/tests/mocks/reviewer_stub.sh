#!/usr/bin/env bash
# reviewer_stub.sh — canned reviewer-subagent output for FR-11/FR-12 contract tests.
# Triggered by READMER_REVIEWER_STUB env var pointing at this script.
#
# Args: <readme-path>
# Stdout: JSON array per reference/reviewer.md §2 schema. One finding object per
#         declared [J] check_id. Default shape: both [J] checks PASS with a
#         ≥40-char quote derived from the README's first line (padded if short).
set -euo pipefail

README="${1:?usage: reviewer_stub.sh <readme-path>}"
[[ -f "$README" ]] || { echo "stub: README not found: $README" >&2; exit 1; }

# Build a ≥40-char quote that is a verbatim substring of the README.
QUOTE="$(head -1 "$README" | tr -d '\r')"
# Pad by repeating line 1 with a space separator until ≥40 chars; the substring
# still grep-matches the README (the original line 1 occurrence).
while [[ "${#QUOTE}" -lt 40 ]]; do
  QUOTE="${QUOTE} ${QUOTE}"
done
# Truncate to 120 to keep the JSON readable.
QUOTE="${QUOTE:0:120}"

# Locate a ≥40-char substring that is genuinely verbatim in the README. We try
# the longest single line ≥40 chars first; fall back to the padded line-1 above.
LONG_LINE="$(awk 'length($0)>=40 {print; exit}' "$README" || true)"
if [[ -n "$LONG_LINE" ]]; then
  QUOTE="${LONG_LINE:0:200}"
fi

# JSON-escape the quote (backslash, double-quote).
ESCAPED="$(printf '%s' "$QUOTE" | python3 -c 'import sys,json; sys.stdout.write(json.dumps(sys.stdin.read()))')"

cat <<JSON
[
  {"check_id": "hero-scope-matches-surface", "verdict": "pass", "fix_note": "", "quote": $ESCAPED},
  {"check_id": "primary-index-by-jtbd",     "verdict": "pass", "fix_note": "", "quote": $ESCAPED}
]
JSON
