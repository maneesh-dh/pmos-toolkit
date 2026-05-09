#!/usr/bin/env bash
# Assert: _shared/resolve-input.md picking rule against 4 sub-fixtures.
# FR-30, FR-31, FR-33; spec §14.1.
set -e
ROOT=${1:-tests/fixtures/resolve-input}
HARNESS=${HARNESS:-tests/scripts/_resolve_input_harness.sh}
fail=0
for case in only-md only-html both neither; do
  actual=$(bash "$HARNESS" "$ROOT/$case" 01_requirements 2>/dev/null || echo "ERROR")
  case "$case" in
    only-md)   expected="01_requirements.md" ;;
    only-html) expected="01_requirements.html" ;;
    both)      expected="01_requirements.html" ;;  # html preferred
    neither)   expected="ERROR" ;;
  esac
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: case=$case expected=$expected actual=$actual"
    fail=1
  else
    echo "OK:   case=$case → $actual"
  fi
done
[ $fail -eq 0 ] || exit 1
echo "PASS: assert_resolve_input.sh (4 cases)"
