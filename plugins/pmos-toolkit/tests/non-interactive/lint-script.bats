#!/usr/bin/env bats
load test_helper

LINT_SCRIPT="${PLUGIN_ROOT:-}/tools/lint-non-interactive-inline.sh"

setup() {
  LINT_SCRIPT="${PLUGIN_ROOT}/tools/lint-non-interactive-inline.sh"
}

@test "lint script exists and is executable" {
  [ -x "$LINT_SCRIPT" ]
}

@test "lint passes when all supported skills have inlined block" {
  run "$LINT_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *PASS* ]]
}

@test "lint exits 2 on missing canonical file" {
  SHARED_FILE_BACKUP="$SHARED_FILE.bak"
  mv "$SHARED_FILE" "$SHARED_FILE_BACKUP"
  run "$LINT_SCRIPT"
  mv "$SHARED_FILE_BACKUP" "$SHARED_FILE"
  [ "$status" -eq 2 ]
}

@test "lint exempts refused skills" {
  skip "Verified post-T26 when /msf-req refusal marker is added"
}
