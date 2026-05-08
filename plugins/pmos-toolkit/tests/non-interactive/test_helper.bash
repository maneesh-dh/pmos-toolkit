#!/usr/bin/env bash
# Bats helpers for non-interactive-mode test suite.
set -euo pipefail

# Resolve plugin root from any test file location.
PLUGIN_ROOT="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/.." && pwd)"
export PLUGIN_ROOT

TOOLS_DIR="${PLUGIN_ROOT}/tools"
SKILLS_DIR="${PLUGIN_ROOT}/skills"
SHARED_FILE="${SKILLS_DIR}/_shared/non-interactive.md"
FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

export TOOLS_DIR SKILLS_DIR SHARED_FILE FIXTURES_DIR

# Build a synthetic SKILL.md fixture with given AskUserQuestion calls.
# Args: $1 = output path; rest = lines of body content
build_skill_fixture() {
  local out="$1"; shift
  {
    echo '---'
    echo 'name: test-skill'
    echo '---'
    echo
    echo '## Phase 0'
    echo
    printf '%s\n' "$@"
  } > "$out"
}

# Stand-in resolver: implements precedence per Section 0 line 1.
# Args: --flag <val|null> --parent <val|null> --settings <val|null> [--default <val>]
# Outputs: "<mode>\t<source>" on stdout
resolve_mode() {
  local flag="" parent="" settings="" default="interactive"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flag) flag="$2"; shift 2;;
      --parent) parent="$2"; shift 2;;
      --settings) settings="$2"; shift 2;;
      --default) default="$2"; shift 2;;
      *) shift;;
    esac
  done
  if [[ -n "$flag" && "$flag" != "null" ]]; then
    printf '%s\tflag\n' "$flag"; return
  fi
  if [[ -n "$parent" && "$parent" != "null" ]]; then
    printf '%s\tparent-skill-prompt\n' "$parent"; return
  fi
  if [[ -n "$settings" && "$settings" != "null" ]]; then
    if [[ "$settings" == "interactive" || "$settings" == "non-interactive" ]]; then
      printf '%s\tsettings:default_mode\n' "$settings"; return
    else
      echo "settings: invalid default_mode value '$settings'; ignoring" >&2
    fi
  fi
  printf '%s\tbuiltin-default\n' "$default"
}
export -f resolve_mode

# Run the canonical awk extractor against a SKILL.md fixture.
# Arg: $1 = path to fixture file
# Stdout: TSV rows <line>\t<has_recommended>\t<defer_only_or_->
run_extractor() {
  local file="$1"
  local extractor
  extractor="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
    | awk '/^```awk$/{flag=1;next}/^```$/{flag=0}flag')"
  awk "$extractor" "$file"
}
export -f run_extractor
