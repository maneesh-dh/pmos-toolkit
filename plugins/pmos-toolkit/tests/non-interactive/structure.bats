#!/usr/bin/env bats
load test_helper

@test "non-interactive.md exists" {
  [ -f "$SHARED_FILE" ]
}

@test "non-interactive.md has Section 0 markers" {
  grep -q '<!-- non-interactive-block:start -->' "$SHARED_FILE"
  grep -q '<!-- non-interactive-block:end -->' "$SHARED_FILE"
}

@test "non-interactive.md has awk-extractor markers" {
  grep -q '<!-- awk-extractor:start -->' "$SHARED_FILE"
  grep -q '<!-- awk-extractor:end -->' "$SHARED_FILE"
}

@test "Section 0 prescribes resolver precedence" {
  awk '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/' "$SHARED_FILE" \
    | grep -qE 'flag.*parent.*settings.*default|flag > parent_marker > settings'
}

@test "Section 0 references the awk extractor" {
  awk '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/' "$SHARED_FILE" \
    | grep -q 'awk-extractor'
}
