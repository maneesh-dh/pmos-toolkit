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

# ── L1 evaluator (T6 size/shape + T7 debug/hygiene) ──────────────────────────
# Single python pass over scanned.files_for_rules. Severity is rewritten in the
# final jq -n via effective_severity, so L3 demotes/promotes flow through.
# T6 rules: U001 (file>500), U002 (TS fn>100), U003 (args>4), U006 (path depth).
# T7 rules: U004 (console.log|print( in src/, excl tests/,scripts/),
#           U005 (TODO/FIXME/XXX with git-blame committer-time > 90d),
#           U007 (file lacks top-of-file purpose comment, info-severity),
#           U008 (commented-out code blocks > 5 lines, code-like heuristic).
# Bash 3.2 (default macOS) miscounts double quotes across a quoted heredoc
# embedded inside "$(...)" — workaround: assign without the outer quotes.
# The variable value is preserved verbatim; quote $findings_json at use site.
findings_json=$(
  python3 - "$LOADER_JSON" "$SCAN_ROOT" <<'PY'
import json, os, re, subprocess, sys, time

loader = json.loads(sys.argv[1])
scan_root = sys.argv[2]
files = loader["scanned"]["files_for_rules"]

CONSOLE_LOG_OR_PRINT = re.compile(r'console\.log|print\(')
TS_FN_START = re.compile(r'^\s*(?:export\s+)?(?:async\s+)?function\s+\w+')
TS_FN_OR_CTOR_SIG = re.compile(r'(?:function\s+\w+|constructor)\s*\(([^)]*)\)')
TODO_RE = re.compile(r'\b(TODO|FIXME|XXX)\b')
COMMENT_LINE_RE = re.compile(r'^\s*(//|#)')
CODE_CHARS = set('(){};=')
HEX = set('0123456789abcdef')
# U009 hardcoded-credential patterns (block). Use \x22 / \x27 for the quote
# class instead of literal ["'] — bash 3.2 (default macOS) miscounts unbalanced
# single quotes across a $(... <<'PY' ...) heredoc once the body grows past a
# threshold; \xNN keeps the literal quote count in the body even.
U009_RE = re.compile(
    r'AKIA[0-9A-Z]{16}'
    r'|sk-[a-zA-Z0-9]{20,}'
    r'|(?:api[-_]?key|secret|password|token)\s*=\s*[\x22\x27][A-Za-z0-9_\-]{16,}[\x22\x27]'
    r'|-----BEGIN [A-Z ]+PRIVATE KEY-----',
    re.IGNORECASE,
)
# U010 stub-on-main-path patterns (block). main-code-path = NOT under
# tests/ or scripts/ — same path-segment rule as U004.
U010_RE = re.compile(r'raise\s+NotImplementedError|throw\s+new\s+Error\([\x22\x27]TBD')

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

def run_git_blame(rel):
    """Return dict[line_no_1idx -> committer-time unix int], or None on failure
    (FR-32 graceful-degrade: file untracked, no git, not a repo, timeout)."""
    try:
        r = subprocess.run(
            ["git", "-C", scan_root, "blame", "--line-porcelain", rel],
            capture_output=True, text=True, timeout=10,
        )
        if r.returncode != 0:
            return None
    except (OSError, subprocess.TimeoutExpired):
        return None
    line_to_time = {}
    sha_to_time = {}
    current_sha = None
    current_final_line = None
    for bl in r.stdout.splitlines():
        if not bl:
            continue
        if bl.startswith('\t'):
            if current_sha is not None and current_final_line is not None:
                t = sha_to_time.get(current_sha)
                if t is not None:
                    line_to_time[current_final_line] = t
            current_sha = None
            current_final_line = None
            continue
        parts = bl.split(' ')
        if parts and len(parts[0]) >= 7 and all(c in HEX for c in parts[0].lower()) and len(parts) >= 3:
            current_sha = parts[0]
            try:
                current_final_line = int(parts[2])
            except (ValueError, IndexError):
                current_final_line = None
        elif bl.startswith('committer-time ') and current_sha is not None:
            try:
                sha_to_time[current_sha] = int(bl.split(' ', 1)[1])
            except ValueError:
                pass
    return line_to_time

cutoff_unix = int(time.time()) - (90 * 86400)
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

    rel_segs = rel.replace("\\", "/").split("/")
    in_excluded_path = any(seg in ("tests", "scripts") for seg in rel_segs)
    is_ts = rel.endswith((".ts", ".tsx"))

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
    if rel_segs and rel_segs[0] == "src" and (len(rel_segs) - 1) > 4:
        findings.append({
            "rule_id": "U006",
            "severity": "warn",
            "file": rel,
            "line": 1,
            "message": f"path depth {len(rel_segs) - 1} after src/ exceeds 4",
            "source_citation": "principles.yaml#U006",
            "suppressed_by": None,
        })

    # U004 — console.log | print( (T7 formalised: applies to all exts under
    # the rule pipeline; excludes paths under tests/ or scripts/ per
    # principles.yaml#U004 `paths:src/;exclude:tests/,scripts/`).
    if not in_excluded_path:
        for idx, line in enumerate(lines, 1):
            if CONSOLE_LOG_OR_PRINT.search(line):
                findings.append({
                    "rule_id": "U004",
                    "severity": "warn",
                    "file": rel,
                    "line": idx,
                    "message": "console.log / print( forbidden outside scripts/, tests/",
                    "source_citation": "principles.yaml#U004",
                    "suppressed_by": None,
                })

    # U009 — hardcoded credential / API-key patterns (block-severity).
    # All files in the rule pipeline; no path exclusion (secrets are an
    # incident wherever they appear).
    for idx, line in enumerate(lines, 1):
        if U009_RE.search(line):
            findings.append({
                "rule_id": "U009",
                "severity": "block",
                "file": rel,
                "line": idx,
                "message": "hardcoded credential / API-key pattern detected",
                "source_citation": "principles.yaml#U009",
                "suppressed_by": None,
            })

    # U010 — NotImplementedError / throw new Error('TBD') on main code path
    # (block-severity). Excludes paths under tests/ or scripts/.
    if not in_excluded_path:
        for idx, line in enumerate(lines, 1):
            if U010_RE.search(line):
                findings.append({
                    "rule_id": "U010",
                    "severity": "block",
                    "file": rel,
                    "line": idx,
                    "message": "stub on main code path: NotImplementedError / TBD",
                    "source_citation": "principles.yaml#U010",
                    "suppressed_by": None,
                })

    # U005 — TODO/FIXME/XXX with blame committer-time > 90 days old.
    # Run blame only when the file has at least one matching line. Graceful
    # degrade: if blame is unavailable (no git / untracked / timeout), skip.
    todo_lines = [(idx, line) for idx, line in enumerate(lines, 1) if TODO_RE.search(line)]
    if todo_lines:
        blame = run_git_blame(rel)
        if blame:
            for idx, line in todo_lines:
                t = blame.get(idx)
                if t is not None and t < cutoff_unix:
                    age_days = (int(time.time()) - t) // 86400
                    findings.append({
                        "rule_id": "U005",
                        "severity": "warn",
                        "file": rel,
                        "line": idx,
                        "message": f"TODO/FIXME/XXX is {age_days} days old; > 90 days threshold",
                        "source_citation": "principles.yaml#U005",
                        "suppressed_by": None,
                    })

    # U007 — first non-blank line should be a comment (info-severity).
    first_content = next((l for l in lines if l.strip()), None)
    if first_content is not None:
        stripped = first_content.lstrip()
        if not (stripped.startswith('//') or stripped.startswith('#') or stripped.startswith('/*')):
            findings.append({
                "rule_id": "U007",
                "severity": "info",
                "file": rel,
                "line": 1,
                "message": "file lacks a top-of-file purpose comment",
                "source_citation": "principles.yaml#U007",
                "suppressed_by": None,
            })

    # U008 — > 5 consecutive commented lines whose content looks like code.
    run_start = None
    run_len = 0
    code_like = False
    def maybe_emit_run(start, length, ok):
        if start is not None and length > 5 and ok:
            findings.append({
                "rule_id": "U008",
                "severity": "warn",
                "file": rel,
                "line": start,
                "message": f"commented-out code block: {length} consecutive lines",
                "source_citation": "principles.yaml#U008",
                "suppressed_by": None,
            })
    for idx, line in enumerate(lines, 1):
        if COMMENT_LINE_RE.match(line):
            if run_start is None:
                run_start = idx
                run_len = 0
                code_like = False
            run_len += 1
            if any(c in line for c in CODE_CHARS):
                code_like = True
        else:
            maybe_emit_run(run_start, run_len, code_like)
            run_start = None
            run_len = 0
            code_like = False
    maybe_emit_run(run_start, run_len, code_like)

    if is_ts:
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
)

# ── L2 delegated tool: dependency-cruiser (T9, FR-30/32/33) ──────────────────
# Runs only when stacks_detected includes "ts". Graceful-degrade per FR-32:
# missing npx/depcruise → tools_skipped += "dependency-cruiser", findings=[].
# Invocation: `npx --no-install depcruise --output-type json --config <cfg> $SCAN_ROOT`
# from within $SCAN_ROOT so the project's own typescript peer is picked up.
# Violations are mapped name → rule_id (.depcruise.cjs names rules TS001-TS004
# 1:1 with principles.yaml); severity is rewritten downstream via effective_severity.
TOOLS_SKIPPED=()
STACKS=$(echo "$LOADER_JSON" | jq -r '.stacks_detected | join(",")')
depcruise_findings='[]'
if echo ",$STACKS," | grep -q ',ts,'; then
  echo "[delegated] dependency-cruiser: check available" 1>&2
  # Run from $SCAN_ROOT first to honour project-local typescript; fall back to
  # $SKILL_DIR (which ships dep-cruiser + typescript as devDeps) so the skill
  # works on projects that don't install typescript themselves.
  dc_cwd=""
  if (cd "$SCAN_ROOT" && npx --no-install depcruise --version >/dev/null 2>&1); then
    dc_cwd="$SCAN_ROOT"
  elif (cd "$SKILL_DIR" && npx --no-install depcruise --version >/dev/null 2>&1); then
    dc_cwd="$SKILL_DIR"
  fi
  if [ -n "$dc_cwd" ]; then
    dc_cfg="$SKILL_DIR/tools/.depcruise.cjs"
    scan_abs="$(cd "$SCAN_ROOT" && pwd)"
    # `timeout` is GNU; macOS ships `gtimeout` only when coreutils is installed.
    # Fall through to a no-timeout invocation if neither is present.
    dc_timeout=""
    if command -v timeout >/dev/null 2>&1; then dc_timeout="timeout 60"
    elif command -v gtimeout >/dev/null 2>&1; then dc_timeout="gtimeout 60"
    fi
    echo "[delegated] $dc_timeout npx --no-install depcruise --output-type json --config $dc_cfg $scan_abs (cwd=$dc_cwd)" 1>&2
    dc_start=$(date +%s)
    dc_out=$(cd "$dc_cwd" && $dc_timeout npx --no-install depcruise \
      --output-type json --config "$dc_cfg" "$scan_abs" 2>/tmp/depcruise.err) || true
    dc_end=$(date +%s)
    echo "[delegated] duration: $((dc_end-dc_start))s" 1>&2
    if [ -n "$dc_out" ]; then
      depcruise_findings=$(echo "$dc_out" | jq '[.summary.violations[] | {
        rule_id: .rule.name,
        file: (.from // "<unknown>"),
        line: 1,
        severity: (if .rule.severity == "error" then "block"
                   elif .rule.severity == "warn" then "warn"
                   else "info" end),
        message: (.comment // (.rule.name + " — see principles.yaml")),
        source_citation: ("principles.yaml#" + .rule.name),
        suppressed_by: null
      }]')
    fi
  else
    echo "[warn] dependency-cruiser not available; skipping TS L2 declarative checks (FR-32)" 1>&2
    TOOLS_SKIPPED+=("dependency-cruiser")
  fi
fi

# Merge depcruise findings into the unified findings array.
findings_json=$(jq -n \
  --argjson a "$findings_json" \
  --argjson b "$depcruise_findings" \
  '$a + $b')

# ── L2 delegated tool: ruff (T10, FR-31/32/33) ───────────────────────────────
# Runs only when stacks_detected includes "py". Graceful-degrade per FR-32:
# missing `ruff` on PATH → tools_skipped += "ruff", findings=[].
# Invocation: `ruff check --output-format=json --quiet --select=TID252,F401,F403,F405,B006 $SCAN_ROOT`
# from within $SCAN_ROOT so a project's own pyproject (e.g. ban-relative-imports
# setting for TID252) is honoured. `--quiet` suppresses the trailing status
# line that ruff 0.15+ otherwise prints to stdout (would corrupt JSON parse).
# Code mapping per principles.yaml: TID252→PY001, F401→PY002,
# F403/F405→PY003, B006→PY004.
ruff_findings='[]'
if echo ",$STACKS," | grep -q ',py,'; then
  echo "[delegated] ruff: check available" 1>&2
  if command -v ruff >/dev/null 2>&1 && ruff --version >/dev/null 2>&1; then
    rf_timeout=""
    if command -v timeout >/dev/null 2>&1; then rf_timeout="timeout 60"
    elif command -v gtimeout >/dev/null 2>&1; then rf_timeout="gtimeout 60"
    fi
    scan_abs="$(cd "$SCAN_ROOT" && pwd)"
    echo "[delegated] $rf_timeout ruff check --output-format=json --quiet --select=TID252,F401,F403,F405,B006 $scan_abs" 1>&2
    rf_start=$(date +%s)
    rf_out=$(cd "$SCAN_ROOT" && $rf_timeout ruff check \
      --output-format=json --quiet \
      --select=TID252,F401,F403,F405,B006 \
      "$scan_abs" 2>/tmp/ruff.err) || true
    rf_end=$(date +%s)
    echo "[delegated] duration: $((rf_end-rf_start))s" 1>&2
    if [ -n "$rf_out" ]; then
      ruff_findings=$(echo "$rf_out" | jq --arg root "$scan_abs" '[.[] | {
        rule_id: (
          if .code == "TID252" then "PY001"
          elif .code == "F401" then "PY002"
          elif .code == "F403" or .code == "F405" then "PY003"
          elif .code == "B006" then "PY004"
          else ("PY-" + .code) end
        ),
        file: (.filename | sub("^" + $root + "/?"; "")),
        line: (.location.row // 1),
        severity: (if .severity == "error" then "warn" else "info" end),
        message: .message,
        source_citation: (
          if .code == "TID252" then "principles.yaml#PY001"
          elif .code == "F401" then "principles.yaml#PY002"
          elif .code == "F403" or .code == "F405" then "principles.yaml#PY003"
          elif .code == "B006" then "principles.yaml#PY004"
          else ("ruff#" + .code) end
        ),
        suppressed_by: null
      }]')
    fi
  else
    echo "[warn] ruff not available; skipping Py L2 declarative checks (FR-32)" 1>&2
    TOOLS_SKIPPED+=("ruff")
  fi
fi

# Merge ruff findings.
findings_json=$(jq -n \
  --argjson a "$findings_json" \
  --argjson b "$ruff_findings" \
  '$a + $b')

# Build tools_skipped JSON array (empty when no tool was skipped).
tools_skipped_json='[]'
if [ "${#TOOLS_SKIPPED[@]}" -gt 0 ]; then
  tools_skipped_json=$(printf '%s\n' "${TOOLS_SKIPPED[@]}" | jq -R . | jq -s .)
fi

END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --argjson f "$findings_json" \
  --argjson loader "$LOADER_JSON" \
  --argjson tools_skipped "$tools_skipped_json" \
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
    tools_skipped: $tools_skipped,
    findings: ($f
      | map(. + { severity: ($loader.effective_severity[.rule_id] // .severity) })
      | sort_by({block:0, warn:1, info:2}[.severity] // 9, .file, .line, .rule_id))
  }'
