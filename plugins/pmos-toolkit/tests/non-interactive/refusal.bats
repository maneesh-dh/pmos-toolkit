#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

FIX="${PLUGIN_ROOT:-}/tests/non-interactive/fixtures/refusal-msf-req-shape.md"

setup() {
  FIX="${FIXTURES_DIR}/refusal-msf-req-shape.md"
}

@test "FR-07 case 1: refusal marker + --non-interactive → exit 64 + matching stderr" {
  run --separate-stderr simulate_refusal_check \
    --skill-name msf-req --skill-file "$FIX" --mode non-interactive
  [ "$status" -eq 64 ]
  [[ "$stderr" =~ ^--non-interactive\ not\ supported\ by\ /msf-req:\ recommendations-only\ with\ free-form\ input ]]
  [[ "$stderr" == *"--apply-edits"* ]]
}

@test "FR-07.2 case 2: refusal is one-directional (--interactive does NOT trigger refusal)" {
  run --separate-stderr simulate_refusal_check \
    --skill-name msf-req --skill-file "$FIX" --mode interactive
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}
