#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  load_parser_snippet
  ART="$(mktemp)"
}
teardown() { rm -f "$ART"; }

@test "FR-09 case 1: artifact with 3 OQ entries → parser emits 3-element JSON array" {
  cat > "$ART" <<'EOF'
# Test artifact

## Open Questions (Non-Interactive Run)

```yaml
id: OQ-001
severity: Blocker
prompt: "destructive overwrite?"
```

```yaml
id: OQ-002
severity: Should-fix
prompt: "tier?"
```

```yaml
id: OQ-003
severity: Auto
prompt: "docs path?"
```
EOF
  run parse_open_questions "$ART"
  [ "$status" -eq 0 ]
  local len; len=$(echo "$output" | jq 'length' 2>/dev/null || echo "?")
  [ "$len" = "3" ]
}

@test "FR-09.2 case 2: artifact with no OQ block → parser emits [] (exit 0)" {
  cat > "$ART" <<'EOF'
# Test artifact

## Some other section

No OQ block here.
EOF
  run parse_open_questions "$ART"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length' 2>/dev/null || echo "?")" = "0" ]
}

@test "FR-09.2 case 3: artifact with malformed YAML in one block → parser is robust (does not crash)" {
  cat > "$ART" <<'EOF'
## Open Questions (Non-Interactive Run)

```yaml
id: OQ-001
severity: Blocker
prompt: "good entry"
```

```yaml
id: OQ-002
 severity: Should-fix
prompt: "bad entry"
```
EOF
  run parse_open_questions "$ART"
  [ "$status" -eq 0 ]
  local len; len=$(echo "$output" | jq 'length' 2>/dev/null || echo "?")
  [[ "$len" =~ ^[0-9]+$ ]]
}
