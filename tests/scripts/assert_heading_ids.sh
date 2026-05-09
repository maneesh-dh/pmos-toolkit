#!/usr/bin/env bash
# Assert: every <h2> and <h3> in fixture HTML carries an id attribute.
# FR-03.1, FR-72; spec §14.1.
set -e
FIXTURE=${1:-tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture}
fail=0
for html in $(find "$FIXTURE" -name "*.html" -not -name "index.html"); do
  bad=$(awk '/<h[23][[:space:]>]/{print NR": "$0}' "$html" | grep -vE 'id=' | wc -l | tr -d ' ' || true)
  if [ "$bad" -gt 0 ]; then
    echo "FAIL: $html has $bad heading(s) without id:"
    awk '/<h[23][[:space:]>]/{print NR": "$0}' "$html" | grep -vE 'id=' || true
    fail=1
  fi
done
[ $fail -eq 0 ] || exit 1
echo "PASS: assert_heading_ids.sh"
