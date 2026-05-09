#!/usr/bin/env bash
# Assert: every fixture *.html has a sibling *.sections.json with unique ids,
# and every id resolves to an <h2 id>/<h3 id>/<section id> in the HTML.
# FR-70, FR-71; spec §14.1.
set -e
FIXTURE=${1:-tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture}
fail=0
for html in $(find "$FIXTURE" -name "*.html" -not -name "index.html"); do
  sections="${html%.html}.sections.json"
  if [ ! -f "$sections" ]; then
    echo "FAIL: $html missing $sections"
    fail=1
    continue
  fi
  dup=$(jq -r '.sections[].id' "$sections" | sort | uniq -d)
  if [ -n "$dup" ]; then
    echo "FAIL: $sections has duplicate ids: $dup"
    fail=1
    continue
  fi
  for id in $(jq -r '.sections[].id' "$sections"); do
    if ! grep -qE "id=[\"']$id[\"']" "$html"; then
      echo "FAIL: $html missing id=$id (declared in $sections)"
      fail=1
    fi
  done
done
[ $fail -eq 0 ] || exit 1
echo "PASS: assert_sections_contract.sh"
