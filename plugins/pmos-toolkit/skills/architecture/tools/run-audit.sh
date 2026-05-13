#!/usr/bin/env bash
# /architecture audit — tracer bullet (T1).
# Scans <root> for `console.log` in .ts files; emits JSON report to stdout.
# Subsequent tasks (T2+) widen this into a full rule-loader-driven evaluator.

set -euo pipefail

SCAN_ROOT="${1:-.}"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: /architecture requires jq. Install via brew/apt/dnf, then re-run." >&2
  exit 64
}

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: /architecture requires python3 (with PyYAML). Install, then re-run." >&2
  exit 64
}

# Plugin-shipped principles.yaml — validator stub (T2). T3 wires the full loader.
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_YAML="${RUN_AUDIT_PLUGIN_YAML:-$SKILL_DIR/principles.yaml}"
python3 -c "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" "$PLUGIN_YAML" 2>/tmp/run-audit-yaml.err || {
  echo "ERROR: plugin principles.yaml at $PLUGIN_YAML failed to parse: $(cat /tmp/run-audit-yaml.err)" >&2
  exit 64
}

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

findings_json="$(
  grep -rn --include='*.ts' 'console\.log' "$SCAN_ROOT" 2>/dev/null \
    | awk -F: '{
        printf "{\"rule_id\":\"U004\",\"severity\":\"warn\",\"file\":\"%s\",\"line\":%s,\"message\":\"console.log forbidden in src/\",\"source_citation\":\"principles.yaml#U004\",\"suppressed_by\":null}\n", $1, $2
      }' \
    | jq -s .
)"

END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --argjson f "$findings_json" \
  --arg start "$START" \
  --arg end "$END" \
  --arg root "$SCAN_ROOT" \
  '{
    schema_version: 1,
    run: { started_at: $start, finished_at: $end, duration_s: 0.0 },
    scan_root: $root,
    findings: $f
  }'
