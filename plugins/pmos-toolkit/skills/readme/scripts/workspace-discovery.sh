#!/usr/bin/env bash
# workspace-discovery.sh <repo-root> | --selftest
# Probes the 8 supported workspace-manifest formats at <repo-root>, applies
# F15 precedence on multi-manifest single-stack repos, and emits JSON.
#
# F15 precedence chain (FR-WS-3):
#   User-override -> Cargo.toml#workspace -> pnpm-workspace.yaml ->
#   package.json#workspaces -> go.work -> pyproject.toml#tool.uv.workspace
# Lerna defers to package.json#workspaces when both are present; alone it
# is the primary.
# nx.json and turbo.json are descriptors only — never enumeration sources;
# they appear as secondaries when present alongside a real source.
#
# T8 scope: detects the `primary` field (the T8 deliverable) and lists
# `secondaries`. `packages: []` is intentionally a stub — T9 will fill in
# glob resolution. `repo_type` is `monorepo-root` when any workspace
# manifest is present, else `unknown` (T10 will refine).
#
# Bash 3.2 portable (macOS default): no associative arrays, no mapfile,
# no `${var^^}`, no `read -d`, no `[[ -v ]]`.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

# --- detectors ----------------------------------------------------------------

has_pnpm_workspace() { [ -f "$1/pnpm-workspace.yaml" ]; }

has_pkg_json_workspaces() {
  # package.json with a `workspaces` key (array OR object form per FR-WS-2)
  local pj="$1/package.json"
  [ -f "$pj" ] || return 1
  python3 - "$pj" <<'PY' >/dev/null 2>&1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
w = d.get("workspaces")
if w is None:
    sys.exit(1)
# Either list form or object form with `packages`
if isinstance(w, list) and w:
    sys.exit(0)
if isinstance(w, dict) and w.get("packages"):
    sys.exit(0)
sys.exit(1)
PY
}

has_lerna() { [ -f "$1/lerna.json" ]; }
has_nx() { [ -f "$1/nx.json" ]; }
has_turbo() { [ -f "$1/turbo.json" ]; }

has_cargo_workspace() {
  local f="$1/Cargo.toml"
  [ -f "$f" ] || return 1
  grep -q '^\[workspace\]' "$f"
}

has_go_work() { [ -f "$1/go.work" ]; }

has_uv_workspace() {
  local f="$1/pyproject.toml"
  [ -f "$f" ] || return 1
  # Bracket-class avoids shell quoting trouble; matches [tool.uv.workspace]
  grep -q '^\[tool\.uv\.workspace\]' "$f"
}

# --- probe + precedence -------------------------------------------------------

probe_manifests() {
  # Emits one manifest name per line, in detection order.
  local root="$1"
  has_pnpm_workspace      "$root" && printf '%s\n' "pnpm-workspace.yaml"
  has_pkg_json_workspaces "$root" && printf '%s\n' "package.json#workspaces"
  has_lerna               "$root" && printf '%s\n' "lerna.json"
  has_nx                  "$root" && printf '%s\n' "nx.json"
  has_turbo               "$root" && printf '%s\n' "turbo.json"
  has_cargo_workspace     "$root" && printf '%s\n' "Cargo.toml#workspace"
  has_go_work             "$root" && printf '%s\n' "go.work"
  has_uv_workspace        "$root" && printf '%s\n' "pyproject.toml#tool.uv.workspace"
  return 0
}

apply_f15_precedence() {
  # stdin: detected manifest names (one per line)
  # stdout: line 1 = primary (or empty), line 2... = secondaries
  local detected
  detected="$(cat)"

  has_in_list() {
    # $1 = needle, stdin = haystack
    local n="$1"
    printf '%s\n' "$detected" | grep -Fxq "$n"
  }

  local primary=""
  # F15 chain (user-override is plumbed by /readme; not handled here)
  if has_in_list "Cargo.toml#workspace"; then
    primary="Cargo.toml#workspace"
  elif has_in_list "pnpm-workspace.yaml"; then
    primary="pnpm-workspace.yaml"
  elif has_in_list "package.json#workspaces"; then
    primary="package.json#workspaces"
  elif has_in_list "go.work"; then
    primary="go.work"
  elif has_in_list "pyproject.toml#tool.uv.workspace"; then
    primary="pyproject.toml#tool.uv.workspace"
  elif has_in_list "lerna.json"; then
    # Lerna defers to package.json#workspaces — only primary when alone.
    primary="lerna.json"
  fi

  printf '%s\n' "$primary"
  # Secondaries: every detected manifest except the primary.
  printf '%s\n' "$detected" | while IFS= read -r m; do
    [ -n "$m" ] || continue
    [ "$m" = "$primary" ] && continue
    printf '%s\n' "$m"
  done
}

# --- JSON emit ----------------------------------------------------------------

emit_json() {
  # $1 = primary, $2..$N = secondaries
  local primary="$1"; shift
  local repo_type="unknown"
  [ -n "$primary" ] && repo_type="monorepo-root"
  python3 - "$primary" "$repo_type" "$@" <<'PY'
import json, sys
primary = sys.argv[1]
repo_type = sys.argv[2]
secondaries = sys.argv[3:]
out = {
    "primary": primary if primary else None,
    "secondaries": secondaries,
    "packages": [],  # T9 will populate via glob resolution
    "repo_type": repo_type,
}
json.dump(out, sys.stdout)
sys.stdout.write("\n")
PY
}

discover() {
  local root="$1"
  [ -d "$root" ] || readme::die "not a directory: $root"
  local detected
  detected="$(probe_manifests "$root")"
  local ranked
  ranked="$(printf '%s\n' "$detected" | apply_f15_precedence)"
  local primary=""
  local -a secondaries
  secondaries=()
  local first=1
  # Bash 3.2-portable line iteration (no mapfile, no read -d).
  while IFS= read -r line; do
    if [ "$first" = "1" ]; then
      primary="$line"
      first=0
    else
      [ -n "$line" ] && secondaries+=("$line")
    fi
  done <<EOF
$ranked
EOF
  if [ "${#secondaries[@]}" -eq 0 ]; then
    emit_json "$primary"
  else
    emit_json "$primary" "${secondaries[@]}"
  fi
}

# --- selftest -----------------------------------------------------------------

selftest() {
  # T8 stub selftest: confirm the 8 packaged fixtures detect the expected primary.
  # T10 will land the real 20-repo gate.
  local fixroot="$HERE/../tests/fixtures/workspaces"
  local pass=0 fail=0
  # heredoc + IFS-read for tabular data (Bash 3.2-portable).
  while IFS='|' read -r dir expected; do
    [ -n "$dir" ] || continue
    local got
    got="$(discover "$fixroot/$dir" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("primary") or "")')"
    if [ "$got" = "$expected" ]; then
      printf '  OK   %s -> %s\n' "$dir" "$got"
      pass=$((pass + 1))
    else
      printf '  FAIL %s -> got=%s want=%s\n' "$dir" "$got" "$expected"
      fail=$((fail + 1))
    fi
  done <<'TABLE'
01_pnpm|pnpm-workspace.yaml
02_npm-workspaces|package.json#workspaces
03_lerna|lerna.json
04_nx|package.json#workspaces
05_turbo|package.json#workspaces
06_cargo|Cargo.toml#workspace
07_go-work|go.work
08_uv|pyproject.toml#tool.uv.workspace
TABLE
  printf 'selftest: %d/%d\n' "$pass" "$((pass + fail))"
  [ "$fail" -eq 0 ]
}

# --- main ---------------------------------------------------------------------

main() {
  if [ "$#" -lt 1 ]; then
    readme::die "usage: workspace-discovery.sh <repo-root> | --selftest"
  fi
  case "$1" in
    --selftest) selftest ;;
    -h|--help) printf 'usage: workspace-discovery.sh <repo-root> | --selftest\n' ;;
    *) discover "$1" ;;
  esac
}

main "$@"
