#!/usr/bin/env bash
# Helpers for headless `claude -p` integration smoke tests.

bats_require_minimum_version 1.5.0

run_skill_headless() {
  local skill="$1"; shift
  local args="$*"
  local transcript
  transcript="$(mktemp -t pmos-ni-XXXXXX.json)"
  if ! command -v claude >/dev/null 2>&1; then
    skip "claude CLI not installed"
  fi
  claude -p "/$skill $args --non-interactive" \
    --output-format=stream-json \
    --print >"$transcript" 2>/tmp/pmos-ni-stderr.log || true
  echo "$transcript"
}

count_askuserquestion() {
  local transcript="$1"
  grep -c '"name":"AskUserQuestion"' "$transcript" 2>/dev/null || echo 0
}

assert_run_outcome() {
  local artifact="$1"
  local outcome="$2"   # clean | deferred | error
  grep -E "^\*\*Run Outcome:\*\* $outcome" "$artifact"
}
