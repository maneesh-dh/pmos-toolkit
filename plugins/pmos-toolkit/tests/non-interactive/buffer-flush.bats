#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  BUF="$(mktemp)"
  cat > "$BUF" <<'EOF'
```yaml
id: OQ-001
severity: Blocker
prompt: "destructive overwrite?"
reason: destructive
```
```yaml
id: OQ-002
severity: Should-fix
prompt: "tier?"
reason: free-form
```
```yaml
id: OQ-003
severity: Auto
prompt: "docs path?"
suggested: "docs/pmos/ (Recommended)"
reason: auto-picked
```
EOF
  ARTIFACT="$(mktemp)"
  echo "# Test artifact" > "$ARTIFACT"
}

teardown() { rm -f "$BUF" "$ARTIFACT" "${ARTIFACT}.open-questions.md"; }

@test "FR-03.4 case 1: single-md flush — heading + frontmatter counts deferred only" {
  run flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
  [ "$status" -eq 0 ]
  grep -q '^## Open Questions (Non-Interactive Run) — 2 deferred, 1 auto-picked$' "$ARTIFACT"
  grep -q '^\*\*Open Questions:\*\* 2$' "$ARTIFACT"
  grep -q '^\*\*Run Outcome:\*\* deferred$' "$ARTIFACT"
}

@test "FR-03 case 2: empty buffer → no block, no frontmatter, exit 0" {
  : > "$BUF"
  local before_size; before_size=$(wc -c < "$ARTIFACT")
  run flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
  [ "$status" -eq 0 ]
  local after_size; after_size=$(wc -c < "$ARTIFACT")
  [ "$before_size" -eq "$after_size" ]
}

@test "FR-03.2 case 3: non-MD primary → sidecar .open-questions.md created" {
  run flush_buffer --buffer "$BUF" --mode sidecar --target "$ARTIFACT"
  [ "$status" -eq 0 ]
  [ -f "${ARTIFACT}.open-questions.md" ]
  grep -q '^## Open Questions' "${ARTIFACT}.open-questions.md"
  [ "$(head -1 "$ARTIFACT")" = "# Test artifact" ]
  [ "$(wc -l < "$ARTIFACT")" -eq 1 ]
}

@test "FR-03.3 case 4: chat-only → buffer to stderr, no file written" {
  run --separate-stderr flush_buffer --buffer "$BUF" --mode chat-only --target "$ARTIFACT"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"--- OPEN QUESTIONS ---"* ]]
  [[ "$stderr" == *"OQ-001"* ]]
  [ ! -f "${ARTIFACT}.open-questions.md" ]
}

@test "E13 case 5: partial-error flush — partial heading, Run Outcome=error, exit 1" {
  run flush_buffer --buffer "$BUF" --mode partial-error --target "$ARTIFACT"
  [ "$status" -eq 1 ]
  grep -q '^## Open Questions (Non-Interactive Run — partial; skill errored)$' "$ARTIFACT"
  grep -q '^\*\*Run Outcome:\*\* error$' "$ARTIFACT"
}

@test "FR-03.6 case 6: ids regenerate per run — re-flushing same buffer twice yields OQ-001 each time" {
  flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
  grep -q 'id: OQ-001' "$ARTIFACT"
  local first_count; first_count=$(grep -c '^id: OQ-' "$ARTIFACT")
  [ "$first_count" -eq 3 ]

  echo "# Test artifact" > "$ARTIFACT"
  flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
  grep -q 'id: OQ-001' "$ARTIFACT"
  [ "$(grep -c '^id: OQ-' "$ARTIFACT")" -eq 3 ]
  ! grep -q 'id: OQ-004' "$ARTIFACT"
}
