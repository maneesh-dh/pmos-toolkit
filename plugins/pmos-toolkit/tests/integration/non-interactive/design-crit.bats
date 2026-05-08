#!/usr/bin/env bats
# Integration smoke: /design-crit --non-interactive — zero AskUserQuestion events.
# Opt-in: each test takes 30–120s of LLM time. Set PMOS_INTEGRATION=1 to run.

bats_require_minimum_version 1.5.0

load test_helper

setup() {
  [[ -z "${PMOS_INTEGRATION:-}" ]] && skip "set PMOS_INTEGRATION=1 to run"
}

@test "/design-crit headless run emits zero AskUserQuestion events" {
  transcript=$(run_skill_headless design-crit "")
  n=$(count_askuserquestion "$transcript")
  [ "$n" -eq 0 ]
}
