#!/usr/bin/env bash
# simulated_reader_stub.sh — canned persona output for FR-SR-3 contract tests.
# Triggered by READMER_PERSONA_STUB env var pointing at this script.
#
# Args: --persona=<evaluator|adopter|contributor> <readme-path>
# Stdout: per-persona JSON matching reference/simulated-reader.md §2 schema.
set -euo pipefail

persona=""
for arg in "$@"; do
  case "$arg" in
    --persona=*) persona="${arg#--persona=}";;
  esac
done

case "$persona" in
  evaluator)
    # VALID: quote is a verbatim ≥40-char substring of fixture README
    # plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/01_hero-line.md
    # whose line 3 reads:
    #   "ripgrep is a line-oriented search tool for recursively searching the current directory for a regex pattern."
    cat <<'JSON'
{"persona":"evaluator","friction":[{"quote":"ripgrep is a line-oriented search tool for recursively searching the current directory for a regex pattern.","line":3,"severity":"friction","message":"hero line is concrete but a 60s reader still skims past on first glance"}]}
JSON
    ;;
  adopter)
    # EMPTY: tests theater-check trigger when rubric has ≥3 findings.
    echo '{"persona":"adopter","friction":[]}'
    ;;
  contributor)
    # ALTERED: 1-char casing slip in quote — substring-grep must hard-fail.
    # Source: "ripgrep is a line-oriented search tool…" (lowercase r)
    # Altered: "Ripgrep is a line-oriented search tool…" (capital R)
    cat <<'JSON'
{"persona":"contributor","friction":[{"quote":"Ripgrep is a line-oriented search tool for recursively searching the current directory for a regex pattern.","line":3,"severity":"friction","message":"contributing section missing"}]}
JSON
    ;;
  *)
    echo "stub: unknown persona '$persona'" >&2
    exit 2
    ;;
esac
