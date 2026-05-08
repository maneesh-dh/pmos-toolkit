#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
    | awk '/^```awk$/{flag=1;next}/^```$/{flag=0}flag')"
}

@test "FR-04.1+.3: destructive tag wins over (Recommended)" {
  run awk "$EXTRACTOR_AWK" "${FIXTURES_DIR}/destructive-tagged.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\t1\tdestructive' ]]
}

@test "FR-04.2: destructive defer with stop-the-run path emits stderr + exit 2" {
  run --separate-stderr flush_and_exit_destructive \
    --checkpoint-id "phase-1-overwrite" \
    --reason "01_requirements.md exists with downstream 02_spec.md, 03_plan.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Refused destructive operation at phase-1-overwrite:"* ]]
  [[ "$stderr" == *"--interactive"* ]]
}

@test "FR-04.3: audit --strict-keywords warns on untagged destructive-keyword call" {
  run --separate-stderr "${TOOLS_DIR}/audit-recommended.sh" \
    --strict-keywords "${FIXTURES_DIR}/destructive-untagged-keyword.md"
  [[ "$stderr" == *"WARN:"* ]]
  [[ "$stderr" == *"destructive"* || "$stderr" == *"reset"* || "$stderr" == *"discard"* ]]
}
