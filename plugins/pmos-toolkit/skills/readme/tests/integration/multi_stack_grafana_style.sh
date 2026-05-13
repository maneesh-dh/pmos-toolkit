#!/usr/bin/env bash
# multi_stack_grafana_style.sh — MS01 contract: when ≥2 supported manifests
# have DISJOINT package sets, workspace-discovery emits BOTH stacks with
# each package labeled `manifest_source: <name>` (FR-WS-4).
#
# Uses tests/fixtures/workspaces/13_multi-stack-js-go (package.json#workspaces
# + go.work, Grafana-style). Also exercises the 21st overlap-secondary-negative
# fixture to assert the negative-case contract (secondary overlaps primary -> 0
# extra rows, closes residual phase-3-r4).
#
# Bash 3.2-safe.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../scripts"
POS_FIX="$HERE/../fixtures/workspaces/13_multi-stack-js-go"
NEG_FIX="$HERE/../fixtures/workspaces/21_overlap-secondary-negative"

tmp="$(mktemp -d -t readme-multi-stack.XXXXXX)"
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

[ -d "$POS_FIX" ] || { echo "FAIL: positive fixture missing: $POS_FIX"; exit 1; }
[ -d "$NEG_FIX" ] || { echo "FAIL: negative fixture missing: $NEG_FIX"; exit 1; }

# --- Positive: both stacks emitted (FR-WS-4) ---------------------------------
pos_json=$(bash "$SCRIPTS/workspace-discovery.sh" "$POS_FIX" 2>/dev/null)
printf '%s\n' "$pos_json" > "$tmp/pos.json"

js_count=$(printf '%s\n' "$pos_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(1 for p in d.get("packages", []) if p.get("manifest_source") == "package.json#workspaces"))
')
go_count=$(printf '%s\n' "$pos_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(1 for p in d.get("packages", []) if p.get("manifest_source") == "go.work"))
')

if [ "${js_count:-0}" -lt 1 ] || [ "${go_count:-0}" -lt 1 ]; then
  echo "FAIL: MS01 did not emit both stacks (js=${js_count}, go=${go_count})"
  cat "$tmp/pos.json"
  exit 1
fi

# --- Negative: overlap-secondary contributes 0 rows (phase-3-r4) -------------
neg_json=$(bash "$SCRIPTS/workspace-discovery.sh" "$NEG_FIX" 2>/dev/null)
printf '%s\n' "$neg_json" > "$tmp/neg.json"

lerna_rows=$(printf '%s\n' "$neg_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(1 for p in d.get("packages", []) if p.get("manifest_source") == "lerna.json"))
')
prim_rows=$(printf '%s\n' "$neg_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(1 for p in d.get("packages", []) if p.get("manifest_source") == "package.json#workspaces"))
')
sec_listed=$(printf '%s\n' "$neg_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("yes" if "lerna.json" in d.get("secondaries", []) else "no")
')

if [ "${lerna_rows:-0}" -ne 0 ]; then
  echo "FAIL: overlap-secondary unexpectedly contributed ${lerna_rows} lerna.json package rows"
  cat "$tmp/neg.json"
  exit 1
fi
if [ "${prim_rows:-0}" -lt 1 ]; then
  echo "FAIL: primary contributed zero rows on overlap-secondary fixture"
  cat "$tmp/neg.json"
  exit 1
fi
if [ "$sec_listed" != "yes" ]; then
  echo "FAIL: lerna.json not listed as secondary (precedence-only signal lost)"
  cat "$tmp/neg.json"
  exit 1
fi

echo "PASS: multi_stack_grafana_style — positive js=${js_count} go=${go_count}; negative overlap-secondary contributed 0 extra rows (phase-3-r4 closed)"
exit 0
