#!/usr/bin/env bash
# _reviewer_validate.sh — parent-side validation for reviewer-subagent JSON.
# Source-able. Defines readme::reviewer_validate <json> <readme-path>.
# Returns 0 on clean; 1 with stderr message on any violation.
#
# FR-11/FR-12 contract:
#   1. JSON parses as an array.
#   2. check_id set-equality vs declared [J] set in rubric.yaml.
#   3. Each finding's quote is ≥40 chars AND a verbatim substring of the README.

# Resolve rubric.yaml relative to this script. BASH_SOURCE[0] is set when
# sourced from inside a script (the production path) and possibly unset in
# some harness sub-shells; fall back to a git-rev-parse lookup so the
# function stays callable in both contexts.
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  _REVIEWER_VALIDATE_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  : "${READMER_RUBRIC_YAML:=$_REVIEWER_VALIDATE_HERE/../reference/rubric.yaml}"
else
  _REVIEWER_VALIDATE_REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  : "${READMER_RUBRIC_YAML:=$_REVIEWER_VALIDATE_REPO/plugins/pmos-toolkit/skills/readme/reference/rubric.yaml}"
fi

readme::reviewer_validate() {
  local json="$1"
  local readme_path="$2"
  local rubric_yaml="${READMER_RUBRIC_YAML}"
  python3 - "$json" "$readme_path" "$rubric_yaml" <<'PYEOF'
import sys, json
try:
    import yaml
except ImportError:
    sys.stderr.write("reviewer-validate: PyYAML not available\n")
    sys.exit(2)

js, readme_path, rubric_yaml = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    findings = json.loads(js)
except Exception as e:
    sys.stderr.write(f"reviewer returned invalid JSON: {e}\n")
    sys.exit(1)
if not isinstance(findings, list):
    sys.stderr.write(f"reviewer returned non-array JSON: {type(findings).__name__}\n")
    sys.exit(1)

# Declared [J] set from rubric.yaml.
with open(rubric_yaml) as f:
    rubric = yaml.safe_load(f)
declared_j_set = {
    row["id"] for row in (rubric.get("checks") or [])
    if row.get("type") == "[J]"
}
got_ids = {f.get("check_id") for f in findings if isinstance(f, dict)}
missing = declared_j_set - got_ids
extra = got_ids - declared_j_set
if missing or extra:
    sys.stderr.write(
        f"reviewer returned check_ids that do not match rubric.yaml: "
        f"missing={sorted(missing)}, extra={sorted(extra)}\n"
    )
    sys.exit(1)

readme_text = open(readme_path).read()
for f in findings:
    q = (f or {}).get("quote", "")
    if len(q) < 40:
        sys.stderr.write(
            f"reviewer returned quote shorter than 40 chars: {q}\n"
        )
        sys.exit(1)
    if q not in readme_text:
        sys.stderr.write(
            f"reviewer returned quote not found in README: {q[:30]}...\n"
        )
        sys.exit(1)
sys.exit(0)
PYEOF
}
