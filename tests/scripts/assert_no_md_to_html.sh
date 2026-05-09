#!/usr/bin/env bash
# Assert: no md→html converter calls in affected SKILL.md files (G2 enforcement).
# Goal G2; spec §14.1.
#
# Matches:
#   - `pandoc<space>` invocations (server-side)
#   - `marked.parse(` (server-side rendering)
#   - `turndown` references annotated as server-side (the client-side Copy-MD
#      flow is allowed; we look for "server-side" + turndown co-occurrence
#      narrowly, not bare turndown).
set -e
TARGET=${1:-plugins/pmos-toolkit/skills/}
PATTERN='pandoc[[:space:]]+|marked\.parse|turndown[^`]*server-side|server-side[^`]*turndown'
count=$(grep -rE "$PATTERN" "$TARGET" --include="SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -ne 0 ]; then
  echo "FAIL: $count match(es) in $TARGET"
  grep -rnE "$PATTERN" "$TARGET" --include="SKILL.md"
  exit 1
fi
echo "PASS: assert_no_md_to_html.sh"
