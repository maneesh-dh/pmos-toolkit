#!/usr/bin/env bash
# persona_stub_sub40.sh — dedicated mock returning a deliberately sub-40-char
# quote, for the FR-SR-3 regression test (T7). Do NOT use the canonical
# simulated_reader_stub.sh for this — it returns ≥40-char quotes by design.
#
# Args: --persona=<name> <readme-path>
# Stdout: persona JSON with a 18-char quote.
set -euo pipefail

persona=""
for arg in "$@"; do
  case "$arg" in
    --persona=*) persona="${arg#--persona=}";;
  esac
done

cat <<JSON
{"persona":"${persona}","friction":[{"quote":"too short to count","line":1,"severity":"friction","message":"deliberately short for FR-SR-3 regression"}]}
JSON
