#!/usr/bin/env bats
# Integration smoke: /msf-req --non-interactive should exit 64 (refusal).

bats_require_minimum_version 1.5.0

load test_helper

setup() {
  [[ -z "${PMOS_INTEGRATION:-}" ]] && skip "set PMOS_INTEGRATION=1 to run"
  command -v claude >/dev/null 2>&1 || skip "claude CLI not installed"
}

@test "/msf-req refuses non-interactive (exit 64)" {
  set +e
  claude -p "/msf-req --non-interactive /tmp/fixture.md" \
    --output-format=stream-json \
    --print >/dev/null 2>/tmp/msf-req-stderr.log
  ec=$?
  set -e
  [ "$ec" -eq 64 ]
  grep -q "non-interactive: refused" /tmp/msf-req-stderr.log
}
