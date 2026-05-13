#!/usr/bin/env bash
# commit-classifier.sh — map a Conventional-Commit range onto README sections.
#
# Usage:
#   commit-classifier.sh <fixture-or-repo-root> <commit-range>
#   commit-classifier.sh --selftest
#
# Reads the `commit_affinity` table from reference/section-schema.yaml (single
# source of truth), enumerates commits in <commit-range> shape (e.g. base..HEAD),
# classifies each subject by Conventional-Commit type, detects breaking changes
# (`!` after type or `BREAKING CHANGE` in body), and emits JSON:
#
#   {"range": "<range>",
#    "commits": [{"subject":"…","type":"feat","breaking":false,"sections":[…]}],
#    "sections": [<union of all sections>]}
#
# On no conventional-commit subjects: emits `{"sections": [], "warn": "..."}`
# and logs the warn to stderr (FR-UP-2).
#
# Bash 3.2 portable. Sources _lib.sh for readme::log / readme::yaml_get.

set -euo pipefail
# shellcheck disable=SC1091
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_lib.sh"

SCHEMA="$HERE/../reference/section-schema.yaml"

usage() {
  cat >&2 <<'USAGE'
Usage:
  commit-classifier.sh <fixture-or-repo-root> <commit-range>
  commit-classifier.sh --selftest
USAGE
  exit 2
}

# Ensure fixture has a .git/; if not, look for setup.sh sibling and run it.
ensure_git_history() {
  local dir="$1"
  if [ -d "$dir/.git" ]; then return 0; fi
  if [ -f "$dir/setup.sh" ]; then
    ( bash "$dir/setup.sh" >/dev/null )
    return 0
  fi
  readme::die "no .git in $dir and no setup.sh to materialise it"
}

classify_range() {
  local root="$1" range="$2"
  ensure_git_history "$root"
  [ -f "$SCHEMA" ] || readme::die "schema not found: $SCHEMA"
  command -v python3 >/dev/null || readme::die "python3 required"

  # Stream commits as NUL-delimited records: subject\0body\0END\n
  # Then hand off to python3 for classification + JSON emission.
  # NOTE: heredoc-as-script (`python3 - <<PY`) would steal stdin from the git
  # pipe, so we materialise the python program to a temp file and feed git
  # output on stdin.
  local py_tmp
  py_tmp="$(mktemp -t commit-classifier.XXXXXX.py)"
  cat >"$py_tmp" <<'PY'
import sys, json, re, os

schema_path, rng = sys.argv[1], sys.argv[2]

try:
    import yaml
except ImportError:
    sys.stderr.write("[/readme] ERROR: PyYAML required for commit-classifier\n")
    sys.exit(2)

with open(schema_path) as f:
    schema = yaml.safe_load(f) or {}
affinity = schema.get("commit_affinity", {}) or {}

raw = sys.stdin.read()
# Records are subject\0body\0END\n
records = []
cur = []
buf = ""
i = 0
# Simple state machine over the stream.
parts = raw.split("\x00END\n")
for chunk in parts:
    if not chunk:
        continue
    # chunk is `subject\x00body` (body may include newlines / be empty)
    if "\x00" not in chunk:
        continue
    subject, body = chunk.split("\x00", 1)
    subject = subject.lstrip("\n")
    records.append((subject, body))

# Conventional-Commit regex: type(scope)?!?: description
# Types kept in sync with the affinity table + standard set.
TYPE_RE = re.compile(
    r"^(feat|fix|chore|docs|refactor|test|build|ci|perf|revert|style)"
    r"(\([^)]+\))?(!)?: "
)

commits = []
union = []
seen = set()
conv_count = 0

def add_sections(secs):
    for s in secs:
        if s not in seen:
            seen.add(s)
            union.append(s)

for subject, body in records:
    m = TYPE_RE.match(subject)
    if not m:
        commits.append({
            "subject": subject,
            "type": None,
            "breaking": False,
            "sections": [],
        })
        continue
    conv_count += 1
    ctype = m.group(1)
    bang = m.group(3) == "!"
    body_breaking = "BREAKING CHANGE" in body
    breaking = bang or body_breaking

    secs = []
    # 1. Base type affinity
    for s in affinity.get(ctype, []) or []:
        if s not in secs:
            secs.append(s)
    # 2. type! affinity (e.g. feat!, fix!) for bang-breaks
    if bang:
        for s in affinity.get(ctype + "!", []) or []:
            if s not in secs:
                secs.append(s)
    # 3. BREAKING CHANGE footer affinity
    if body_breaking:
        for s in affinity.get("BREAKING CHANGE", []) or []:
            if s not in secs:
                secs.append(s)

    commits.append({
        "subject": subject,
        "type": ctype,
        "breaking": breaking,
        "sections": secs,
    })
    add_sections(secs)

out = {
    "range": rng,
    "commits": commits,
    "sections": union,
}
if conv_count == 0:
    out["sections"] = []
    out["warn"] = "no conventional-commit subjects"
    sys.stderr.write("[/readme] warn: no conventional-commit subjects in range %s\n" % rng)

print(json.dumps(out, indent=2))
PY
  local rc=0
  ( cd "$root" && git log --format='%s%x00%b%x00END' "$range" 2>/dev/null ) \
    | python3 "$py_tmp" "$SCHEMA" "$range" || rc=$?
  rm -f "$py_tmp"
  return "$rc"
}

selftest() {
  local fixtures_dir="$HERE/../tests/fixtures/commits"
  [ -d "$fixtures_dir" ] || readme::die "fixtures dir missing: $fixtures_dir"
  command -v python3 >/dev/null || readme::die "python3 required for --selftest"

  local pass=0 fail=0
  # Format: name|expected|mode  (mode = eq | subset)
  #   eq:     expected == actual (set equality)
  #   subset: expected ⊆ actual (every expected section is in actual)
  local cases="01_feat-only|Features,Usage,Quickstart|eq
02_no-conv-commit||eq
03_breaking|Migration,Changelog|subset"

  local oldifs="$IFS"
  IFS='
'
  for line in $cases; do
    IFS="$oldifs"
    local name="${line%%|*}"
    local rest="${line#*|}"
    local expected="${rest%%|*}"
    local mode="${rest#*|}"
    [ -n "$mode" ] || mode="eq"
    local dir="$fixtures_dir/$name"
    # Range: first commit (initial) .. HEAD — covers commits 2..N.
    ensure_git_history "$dir"
    local first
    first="$( cd "$dir" && git rev-list --max-parents=0 HEAD | head -n1 )"
    local range="${first}..HEAD"
    local out
    if ! out="$( classify_range "$dir" "$range" 2>/dev/null )"; then
      readme::log "selftest: $name CLASSIFY FAIL"
      fail=$((fail + 1))
      IFS='
'
      continue
    fi
    local actual
    actual="$( printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(",".join(d.get("sections", [])))
' )"
    # Set-equality compare (order-independent).
    local match
    match="$( EXPECTED="$expected" ACTUAL="$actual" MODE="$mode" python3 -c '
import os
exp = set(filter(None, os.environ["EXPECTED"].split(",")))
act = set(filter(None, os.environ["ACTUAL"].split(",")))
mode = os.environ["MODE"]
if mode == "subset":
    print("ok" if exp.issubset(act) else "diff")
else:
    print("ok" if exp == act else "diff")
' )"
    if [ "$match" = "ok" ]; then
      readme::log "selftest: $name PASS (sections=[$actual])"
      pass=$((pass + 1))
    else
      readme::log "selftest: $name FAIL (expected=[$expected] actual=[$actual])"
      fail=$((fail + 1))
    fi
    IFS='
'
  done
  IFS="$oldifs"

  readme::log "selftest: $pass passed, $fail failed (of 3)"
  [ "$fail" -eq 0 ] || exit 1
}

main() {
  if [ "$#" -lt 1 ]; then usage; fi
  case "${1:-}" in
    --selftest) selftest ;;
    -h|--help) usage ;;
    *)
      [ "$#" -eq 2 ] || usage
      classify_range "$1" "$2"
      ;;
  esac
}

main "$@"
