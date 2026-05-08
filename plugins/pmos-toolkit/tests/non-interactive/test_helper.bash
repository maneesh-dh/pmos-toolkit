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
