#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

@test "FR-06.1 case 1: marker on first line → mode extracted" {
  run scan_parent_marker --prompt $'[mode: non-interactive]\nVerify phase 1'
  [ "$status" -eq 0 ]
  [ "$output" = "non-interactive" ]
}

@test "FR-06.1 case 2: marker NOT on first line → no match" {
  run scan_parent_marker --prompt $'Hello\n[mode: non-interactive]\n'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "FR-06.1 case 3: malformed marker (missing brackets) → no match" {
  run scan_parent_marker --prompt $'mode: non-interactive\nVerify'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "FR-06.2 case 4: child OQ id prefixes with skill name (e.g. OQ-verify-001)" {
  run format_child_oq_id --child-skill verify --counter 1
  [ "$output" = "OQ-verify-001" ]
  run format_child_oq_id --child-skill verify --counter 12
  [ "$output" = "OQ-verify-012" ]
}
