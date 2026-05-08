#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
    | awk '/^```awk$/{flag=1;next}/^```$/{flag=0}flag')"
  [ -n "$EXTRACTOR_AWK" ]
  FIXTURE="$(mktemp)"
}

teardown() {
  rm -f "$FIXTURE"
}

@test "FR-02 case 1: Recommended option, no defer-only tag → AUTO-PICK (has_recc=1, tag=-)" {
  cat > "$FIXTURE" <<'EOF'
AskUserQuestion: "Pick one"
Options: "Foo (Recommended)", "Bar"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\t1\t-' ]]
}

@test "FR-02 case 2: no Recommended → DEFER (has_recc=0, tag=-)" {
  cat > "$FIXTURE" <<'EOF'
AskUserQuestion: "Pick one"
Options: "Foo", "Bar"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [[ "$output" == *$'\t0\t-' ]]
}

@test "FR-02 case 3: Recommended AND defer-only:destructive adjacent → DEFER wins (has_recc=1, tag=destructive)" {
  cat > "$FIXTURE" <<'EOF'
<!-- defer-only: destructive -->
AskUserQuestion: "Overwrite?"
Options: "Yes (Recommended)", "No"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [[ "$output" == *$'\t1\tdestructive' ]]
}

@test "FR-02 case 4: defer-only tag with blank line between → NOT adjacent (tag=-)" {
  cat > "$FIXTURE" <<'EOF'
<!-- defer-only: destructive -->

AskUserQuestion: "Overwrite?"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [[ "$output" == *$'\t0\t-' ]]
}

@test "FR-02 case 5: free-form (no options) → DEFER (has_recc=0)" {
  cat > "$FIXTURE" <<'EOF'
AskUserQuestion: "Describe the problem"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [[ "$output" == *$'\t0\t-' ]]
}

@test "FR-02 case 6: tag 6 lines above → not adjacent (tag=-)" {
  cat > "$FIXTURE" <<'EOF'
<!-- defer-only: destructive -->
Some intervening content line 1
Some intervening content line 2
Some intervening content line 3
Some intervening content line 4
Some intervening content line 5
AskUserQuestion: "Pick"
EOF
  run awk "$EXTRACTOR_AWK" "$FIXTURE"
  [[ "$output" == *$'\t0\t-' ]]
}
