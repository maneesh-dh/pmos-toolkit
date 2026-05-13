#!/usr/bin/env bash
# /architecture audit — entrypoint.
# T1 shipped a hardcoded U004 grep; T3 added the 3-tier rule loader + L1 cap (FR-21)
# + stack detection (FR-22) + L3 presence (FR-23); T4 adds L3 override merge
# (FR-11/20) + exemption parsing (FR-13) + config keys (FR-14); T5 adds the file
# scanner with gitignore + hardcoded deny-list + extension filter (FR-40/41/42/43,
# D15). Findings still come from the T1 U004 grep, but now driven by the
# enumerated file list, until T6+ wire the rest of the L1 rules.

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
#   effective_severity: {<rule_id>: <severity>},
#   scanned: {total, by_ext, excluded_by_gitignore, excluded_by_fallback,
#             files_for_rules: [<rel-path>, ...]}
# }
# File scanner (FR-40/41/42/43, D15):
#   In a git repo  → enumerate via `git ls-files --cached --others --exclude-standard`
#                    (.gitignore is honored by `--exclude-standard`); a separate
#                    `find` pass counts files dropped by gitignore.
#   Non-git tree   → enumerate via `find -type f -not -path '*/\.git/*'`.
#   Hardcoded deny-list (14 entries from D15): node_modules, .venv, __pycache__,
#     dist, build, .pytest_cache, .ruff_cache, .mypy_cache, coverage, .next,
#     .nuxt, .git, target, vendor — applied as path-segment match.
#   extra_ignore from L3 config (FR-14) unions with the deny-list.
#   Files for the rule pipeline are filtered to .ts .tsx .js .jsx .mjs .cjs .vue .py;
#   all other survivors count toward scanned.total but are not handed to evaluators.
# Merge precedence (FR-20): project L3 > stack L2 > universal L1.
# L1 cap (FR-21): >15 tier=1 plugin rules → exit 64 with exact message.
# Stack detection (FR-22): package.json+tsconfig.json → ts; pyproject/setup/requirements → py.
# L3 (FR-11/23): <scan-root>/.pmos/architecture/principles.yaml — missing → l3_present=false;
#   malformed → exit 64.
# T4 only parses exemptions; reconciliation against ADRs lands in T15.
LOADER_JSON="$(
  python3 - "$PLUGIN_YAML" "$SCAN_ROOT" <<'PY'
import json, os, subprocess, sys, yaml

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

# FR-40/41/42/43, D15 — file enumeration.
DENY_SEGMENTS = (
    "node_modules", ".venv", "__pycache__", "dist", "build",
    ".pytest_cache", ".ruff_cache", ".mypy_cache", "coverage",
    ".next", ".nuxt", ".git", "target", "vendor",
)
SUPPORTED_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".py")

extra_ignore_segments = []
for raw in config["extra_ignore"]:
    seg = str(raw).strip().strip("/")
    if seg:
        extra_ignore_segments.append(seg)

deny_set = set(DENY_SEGMENTS) | set(extra_ignore_segments)

def has_denied_segment(rel_path):
    parts = rel_path.replace("\\", "/").split("/")
    return any(p in deny_set for p in parts)

def find_all_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Always skip .git internals; deny-list filtering runs on the rel path.
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace("\\", "/")
            out.append(rel)
    return out

def in_git_repo(root):
    try:
        r = subprocess.run(
            ["git", "-C", root, "rev-parse", "--is-inside-work-tree"],
            capture_output=True, text=True, check=False,
        )
        return r.returncode == 0 and r.stdout.strip() == "true"
    except FileNotFoundError:
        return False

scanned_total = 0
by_ext = {}
excluded_by_gitignore = 0
excluded_by_fallback = 0
files_for_rules = []

if os.path.isdir(scan_root):
    is_repo = in_git_repo(scan_root)
    all_files = find_all_files(scan_root)

    if is_repo:
        r = subprocess.run(
            ["git", "-C", scan_root, "ls-files", "--cached", "--others",
             "--exclude-standard"],
            capture_output=True, text=True, check=False,
        )
        kept_by_git = set(
            line for line in r.stdout.splitlines() if line.strip()
        )
        # Files visible to `find` but not in the git keep-set are gitignored.
        for rel in all_files:
            if rel not in kept_by_git:
                excluded_by_gitignore += 1
        post_gitignore = [rel for rel in all_files if rel in kept_by_git]
    else:
        post_gitignore = list(all_files)

    for rel in post_gitignore:
        if has_denied_segment(rel):
            excluded_by_fallback += 1
            continue
        ext = os.path.splitext(rel)[1].lower()
        if ext not in SUPPORTED_EXTS:
            # Non-supported survivors (dotfiles, configs, docs) are not handed
            # to evaluators and not counted in scanned.total (per plan §T5
            # inline verification: total counts only the rule-pipeline set).
            continue
        scanned_total += 1
        by_ext[ext] = by_ext.get(ext, 0) + 1
        files_for_rules.append(rel)

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
    "scanned": {
        "total": scanned_total,
        "by_ext": by_ext,
        "excluded_by_gitignore": excluded_by_gitignore,
        "excluded_by_fallback": excluded_by_fallback,
        "files_for_rules": files_for_rules,
    },
}))
PY
)"

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── L1 evaluator (T6 — U001/U002/U003/U006 + U004 from T5) ───────────────────
# Single python pass over scanned.files_for_rules. Severity is rewritten in the
# final jq -n via effective_severity, so L3 demotes/promotes flow through.
# Plan §T6 step 3 calls for bash/awk dispatchers; deviated to python because
# U002 (brace-balanced function-body length) and U003 (paren-balanced arg list)
# are stateful per-file and bash awk for both is illegible vs. a 60-LOC python
# block. Result is identical and verifiable against plan §T6 inline-verify.
findings_json="$(
  python3 - "$LOADER_JSON" "$SCAN_ROOT" <<'PY'
import json, os, re, sys

loader = json.loads(sys.argv[1])
scan_root = sys.argv[2]
files = loader["scanned"]["files_for_rules"]

CONSOLE_LOG = re.compile(r'console\.log')
TS_FN_START = re.compile(r'^\s*(?:export\s+)?(?:async\s+)?function\s+\w+')
TS_FN_OR_CTOR_SIG = re.compile(r'(?:function\s+\w+|constructor)\s*\(([^)]*)\)')

def find_ts_function_spans(lines):
    """Return list of (start_line_1idx, end_line_1idx) for top-level functions."""
    spans = []
    i = 0
    n = len(lines)
    while i < n:
        if TS_FN_START.match(lines[i]):
            start = i
            depth = 0
            saw_open = False
            j = i
            while j < n:
                for ch in lines[j]:
                    if ch == '{':
                        depth += 1
                        saw_open = True
                    elif ch == '}':
                        depth -= 1
                if saw_open and depth <= 0:
                    break
                j += 1
            spans.append((start + 1, j + 1))
            i = j + 1
        else:
            i += 1
    return spans

findings = []

for rel in files:
    full = os.path.join(scan_root, rel)
    if not os.path.isfile(full):
        continue
    try:
        with open(full, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        continue

    # U001 — file > 500 LOC (all supported exts)
    if len(lines) > 500:
        findings.append({
            "rule_id": "U001",
            "severity": "warn",
            "file": rel,
            "line": 1,
            "message": f"file is {len(lines)} lines; exceeds 500-line cap",
            "source_citation": "principles.yaml#U001",
            "suppressed_by": None,
        })

    # U006 — path depth > 4 after src/
    parts = rel.replace("\\", "/").split("/")
    if parts and parts[0] == "src" and (len(parts) - 1) > 4:
        findings.append({
            "rule_id": "U006",
            "severity": "warn",
            "file": rel,
            "line": 1,
            "message": f"path depth {len(parts) - 1} after src/ exceeds 4",
            "source_citation": "principles.yaml#U006",
            "suppressed_by": None,
        })

    is_ts = rel.endswith((".ts", ".tsx"))

    if is_ts:
        # U004 — console.log forbidden in src/
        for idx, line in enumerate(lines, 1):
            if CONSOLE_LOG.search(line):
                findings.append({
                    "rule_id": "U004",
                    "severity": "warn",
                    "file": rel,
                    "line": idx,
                    "message": "console.log forbidden in src/",
                    "source_citation": "principles.yaml#U004",
                    "suppressed_by": None,
                })

        # U002 — TS function body > 100 LOC
        for start, end in find_ts_function_spans(lines):
            if (end - start + 1) > 100:
                findings.append({
                    "rule_id": "U002",
                    "severity": "warn",
                    "file": rel,
                    "line": start,
                    "message": f"function body is {end - start + 1} lines; exceeds 100-line cap",
                    "source_citation": "principles.yaml#U002",
                    "suppressed_by": None,
                })

        # U003 — function or constructor with > 4 args
        # Plan §goal: ">4 args" (≥5 args). 5 args = 4 commas, so commas > 3.
        # (Plan step text "count commas; emit when > 4" was a one-off slip
        # vs. the goal; the inline verification expects U003 to fire on the
        # 5-arg constructor fixture. Following goal-text.)
        text = "".join(lines)
        for m in TS_FN_OR_CTOR_SIG.finditer(text):
            args = m.group(1).strip()
            if not args:
                continue
            commas = args.count(",")
            arg_count = commas + 1
            if arg_count > 4:
                line_no = text[:m.start()].count("\n") + 1
                findings.append({
                    "rule_id": "U003",
                    "severity": "warn",
                    "file": rel,
                    "line": line_no,
                    "message": f"function/constructor has {arg_count} args; exceeds 4",
                    "source_citation": "principles.yaml#U003",
                    "suppressed_by": None,
                })

print(json.dumps(findings))
PY
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
    scanned: ($loader.scanned | del(.files_for_rules)),
    findings: ($f | map(. + { severity: ($loader.effective_severity[.rule_id] // .severity) }))
  }'
