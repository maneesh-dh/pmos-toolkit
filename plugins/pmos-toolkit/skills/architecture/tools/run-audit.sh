#!/usr/bin/env bash
# /architecture audit — entrypoint.
# T1 shipped a hardcoded U004 grep; T3 added the 3-tier rule loader + L1 cap (FR-21)
# + stack detection (FR-22) + L3 presence (FR-23); T4 adds L3 override merge
# (FR-11/20) + exemption parsing (FR-13) + config keys (FR-14). Findings still
# come from the T1 U004 grep until T5+ wire the real scanner.

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

# ── Loader (FR-11/12/13/14/20/21/22/23) ─────────────────────────────────────
# Emits JSON: {
#   tier_1, tier_2_ts, tier_2_py, tier_3, total_loaded,
#   l3_present, stacks_detected,
#   rule_overrides: [{id, fields:{<field>:{before,after}}}],
#   exemptions: [{rule, file, line?, adr, expires?, note?}],
#   config: {adr_path, scan_root, extra_ignore},
#   effective_severity: {<rule_id>: <severity>}
# }
# Merge precedence (FR-20): project L3 > stack L2 > universal L1.
# L1 cap (FR-21): >15 tier=1 plugin rules → exit 64 with exact message.
# Stack detection (FR-22): package.json+tsconfig.json → ts; pyproject/setup/requirements → py.
# L3 (FR-11/23): <scan-root>/.pmos/architecture/principles.yaml — missing → l3_present=false;
#   malformed → exit 64.
# T4 only parses exemptions; reconciliation against ADRs lands in T15.
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

plugin_rules = plugin.get("rules", []) or []
tier_1_rules = [r for r in plugin_rules if r.get("tier") == 1]

# FR-21 — L1 cap.
if len(tier_1_rules) > 15:
    print(f"ERROR: L1 has {len(tier_1_rules)} rules; cap is 15. Demote rules to L2 or remove.", file=sys.stderr)
    sys.exit(64)

# FR-22 — stack detection.
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

tier_2_rules = [r for r in plugin_rules if r.get("tier") == 2 and r.get("stack") in stacks]
tier_2_ts = sum(1 for r in tier_2_rules if r.get("stack") == "ts")
tier_2_py = sum(1 for r in tier_2_rules if r.get("stack") == "py")

# Start the merged set from plugin L1 + filtered L2.
merged = {r["id"]: dict(r) for r in tier_1_rules + tier_2_rules}

# FR-11/14/23 — L3 file.
l3_path = os.path.join(scan_root, ".pmos", "architecture", "principles.yaml")
l3_present = False
l3 = {}
if os.path.isfile(l3_path):
    try:
        with open(l3_path) as f:
            l3 = yaml.safe_load(f) or {}
    except Exception as exc:
        print(f"ERROR: {l3_path} malformed: {exc}", file=sys.stderr)
        sys.exit(64)
    if not isinstance(l3, dict):
        print(f"ERROR: {l3_path} malformed: top-level must be a mapping", file=sys.stderr)
        sys.exit(64)
    l3_present = True

# FR-14 — config keys (defaults when absent).
config = {
    "adr_path": l3.get("adr_path", "docs/adr/"),
    "scan_root": l3.get("scan_root", "."),
    "extra_ignore": list(l3.get("extra_ignore", []) or []),
}

# FR-13 — exemptions passthrough; reconciliation lives in T15.
exemptions = list(l3.get("exemptions", []) or [])

# FR-20 — merge L3 rule overrides onto merged set; track diffs.
rule_overrides = []
tier_3_new = 0
for r in (l3.get("rules", []) or []):
    rid = r.get("id")
    if not rid:
        continue
    if rid in merged:
        base = merged[rid]
        diff = {}
        for field, new_val in r.items():
            if field == "id":
                continue
            old_val = base.get(field)
            if old_val != new_val:
                diff[field] = {"before": old_val, "after": new_val}
                base[field] = new_val
        if diff:
            rule_overrides.append({"id": rid, "fields": diff})
    else:
        # New L3-only rule — adopt as tier 3.
        new_rule = dict(r)
        new_rule.setdefault("tier", 3)
        merged[rid] = new_rule
        tier_3_new += 1

effective_severity = {rid: r.get("severity") for rid, r in merged.items() if r.get("severity")}

print(json.dumps({
    "tier_1": len(tier_1_rules),
    "tier_2_ts": tier_2_ts,
    "tier_2_py": tier_2_py,
    "tier_3": tier_3_new,
    "total_loaded": len(merged),
    "l3_present": l3_present,
    "stacks_detected": stacks,
    "rule_overrides": rule_overrides,
    "exemptions": exemptions,
    "config": config,
    "effective_severity": effective_severity,
}))
PY
)"

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Scanner stub (T5+ replaces with real driver) ──────────────────────────────
# Still the T1 hardcoded U004 grep; severity is rewritten post-grep by jq using
# effective_severity so L3 demotes/promotes flow through.
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
      tier_3: $loader.tier_3,
      total: $loader.total_loaded
    },
    l3_present: $loader.l3_present,
    stacks_detected: $loader.stacks_detected,
    config: $loader.config,
    rule_overrides: $loader.rule_overrides,
    exemptions: $loader.exemptions,
    findings: ($f | map(. + { severity: ($loader.effective_severity[.rule_id] // .severity) }))
  }'
