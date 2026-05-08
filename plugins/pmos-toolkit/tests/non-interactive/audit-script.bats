#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

AUDIT="${PLUGIN_ROOT:-}/tools/audit-recommended.sh"

setup() {
  AUDIT="${TOOLS_DIR}/audit-recommended.sh"
}

@test "FR-05 case 1: clean fixture (all marked) → exit 0" {
  run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-clean.md"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"PASS: all calls"* ]]
}

@test "FR-05 case 2: unmarked call → exit 1 + UNMARKED line on stderr" {
  run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-unmarked.md"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"UNMARKED:"* ]]
  [[ "$stderr" == *"audit-unmarked.md"* ]]
}

@test "FR-05.3 case 3: malformed defer-only reason → exit 1" {
  run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-malformed-tag.md"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"invalid reason 'foobar'"* || "$stderr" == *"UNMARKED"* ]]
}

@test "FR-07.1 case 4: refusal-marked SKILL.md → exit 0 (exempt)" {
  run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-refused.md"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"REFUSED:"* ]]
}
