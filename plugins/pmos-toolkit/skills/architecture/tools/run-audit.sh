#!/usr/bin/env bash
# /architecture audit — entrypoint.
# T1 shipped a hardcoded U004 grep; T3 adds the 3-tier rule loader + L1 cap (FR-21)
# + stack detection (FR-22) + L3 presence (FR-23). Findings still come from the T1
# U004 grep until T5+ wire the real scanner.

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

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_YAML="${RUN_AUDIT_PLUGIN_YAML:-$SKILL_DIR/principles.yaml}"

# ── Loader (FR-20/21/22/23) ──────────────────────────────────────────────────
# Emits JSON: { tier_1, tier_2_ts, tier_2_py, total_loaded, l3_present, stacks_detected }
# Detects stack from SCAN_ROOT manifest files; filters L2 rules by detected stacks.
# L1 cap enforcement (FR-21): >15 tier=1 rules → exit 64 with exact message.
# L3 file (<scan-root>/.pmos/architecture/principles.yaml): missing → l3_present=false;
# malformed → exit 64 with FR-23 message. L3 override merge is T4.
LOADER_JSON="$(
  python3 - "$PLUGIN_YAML" "$SCAN_ROOT" <<'PY'
import json, os, sys, yaml

plugin_path, scan_root = sys.argv[1], sys.argv[2]

try:
    with open(plugin_path) as f:
        plugin = yaml.safe_load(f) or {}
except Exception as exc:
    print(f"ERROR: plugin principles.yaml at {plugin_path} failed to parse: {exc}", file=sys.stderr)
    sys.exit(64)

rules = plugin.get("rules", []) or []
tier_1 = [r for r in rules if r.get("tier") == 1]

# FR-21 — L1 cap.
if len(tier_1) > 15:
    print(f"ERROR: L1 has {len(tier_1)} rules; cap is 15. Demote rules to L2 or remove.", file=sys.stderr)
    sys.exit(64)

# FR-22 — stack detection from SCAN_ROOT.
stacks = []
has_pkg = os.path.isfile(os.path.join(scan_root, "package.json"))
has_tsc = os.path.isfile(os.path.join(scan_root, "tsconfig.json"))
if has_pkg and has_tsc:
    stacks.append("ts")
has_py = (
    os.path.isfile(os.path.join(scan_root, "pyproject.toml"))
    or os.path.isfile(os.path.join(scan_root, "setup.py"))
    or any(
        n.startswith("requirements") and n.endswith(".txt")
        for n in (os.listdir(scan_root) if os.path.isdir(scan_root) else [])
    )
)
if has_py:
    stacks.append("py")

tier_2 = [r for r in rules if r.get("tier") == 2 and r.get("stack") in stacks]
tier_2_ts = sum(1 for r in tier_2 if r.get("stack") == "ts")
tier_2_py = sum(1 for r in tier_2 if r.get("stack") == "py")

# FR-23 — L3 presence (override merge deferred to T4).
l3_path = os.path.join(scan_root, ".pmos", "architecture", "principles.yaml")
l3_present = False
if os.path.isfile(l3_path):
    try:
        with open(l3_path) as f:
            yaml.safe_load(f)
        l3_present = True
    except Exception as exc:
        print(f"ERROR: {l3_path} malformed: {exc}", file=sys.stderr)
        sys.exit(64)

print(json.dumps({
    "tier_1": len(tier_1),
    "tier_2_ts": tier_2_ts,
    "tier_2_py": tier_2_py,
    "total_loaded": len(tier_1) + len(tier_2),
    "l3_present": l3_present,
    "stacks_detected": stacks,
}))
PY
)"

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Scanner stub (T5+ replaces with real driver) ──────────────────────────────
# Still the T1 hardcoded U004 grep; loader output is reported alongside.
findings_json="$(
  { grep -rn --include='*.ts' 'console\.log' "$SCAN_ROOT" 2>/dev/null || true; } \
    | awk -F: '{
        printf "{\"rule_id\":\"U004\",\"severity\":\"warn\",\"file\":\"%s\",\"line\":%s,\"message\":\"console.log forbidden in src/\",\"source_citation\":\"principles.yaml#U004\",\"suppressed_by\":null}\n", $1, $2
      }' \
    | jq -s .
)"

END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --argjson f "$findings_json" \
  --argjson loader "$LOADER_JSON" \
  --arg start "$START" \
  --arg end "$END" \
  --arg root "$SCAN_ROOT" \
  '{
    schema_version: 1,
    run: { started_at: $start, finished_at: $end, duration_s: 0.0 },
    scan_root: $root,
    rules_loaded: {
      tier_1: $loader.tier_1,
      tier_2: ($loader.tier_2_ts + $loader.tier_2_py),
      tier_3: 0,
      total: $loader.total_loaded
    },
    l3_present: $loader.l3_present,
    stacks_detected: $loader.stacks_detected,
    findings: $f
  }'
