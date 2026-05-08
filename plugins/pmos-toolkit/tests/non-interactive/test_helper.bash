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

# Stand-in flush per FR-03 dispatch.
# Args: --buffer <file> --mode <single-md|multi-artifact|sidecar|chat-only|partial-error>
#       --target <artifact-path> [--id-counter-start <N>]
flush_buffer() {
  local buf="" mode="" target="" id_start=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --buffer) buf="$2"; shift 2;;
      --mode) mode="$2"; shift 2;;
      --target) target="$2"; shift 2;;
      --id-counter-start) id_start="$2"; shift 2;;
      *) shift;;
    esac
  done

  local n_deferred=0 n_auto=0
  n_deferred=$(grep -cE '^severity: (Blocker|Should-fix)$' "$buf" || true)
  n_auto=$(grep -cE '^severity: Auto$' "$buf" || true)
  local n_total=$((n_deferred + n_auto))
  local outcome="clean"
  [[ $n_deferred -gt 0 ]] && outcome="deferred"

  local heading="## Open Questions (Non-Interactive Run) — ${n_deferred} deferred, ${n_auto} auto-picked"
  if [[ "$mode" == "partial-error" ]]; then
    heading="## Open Questions (Non-Interactive Run — partial; skill errored)"
    outcome="error"
  fi

  case "$mode" in
    single-md|partial-error)
      if [[ $n_total -gt 0 ]]; then
        {
          echo
          echo "**Mode:** non-interactive"
          echo "**Run Outcome:** $outcome"
          echo "**Open Questions:** $n_deferred"
          echo
          echo "$heading"
          echo
          cat "$buf"
        } >> "$target"
      fi
      [[ "$mode" == "partial-error" ]] && return 1
      return 0
      ;;
    sidecar)
      local sidecar="${target}.open-questions.md"
      {
        echo "$heading"
        echo
        cat "$buf"
      } > "$sidecar"
      return 0
      ;;
    chat-only)
      echo "--- OPEN QUESTIONS ---" >&2
      cat "$buf" >&2
      return 0
      ;;
    multi-artifact)
      local agg
      agg="$(dirname "$target")/_open_questions.md"
      {
        echo "$heading"
        echo
        cat "$buf"
      } > "$agg"
      echo "**Open Questions:** $n_deferred — see _open_questions.md" >> "$target"
      return 0
      ;;
  esac
}
export -f flush_buffer
