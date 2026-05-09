#!/usr/bin/env bash
# Assert: every <a href="X.html#frag"> in fixture HTMLs resolves to a real
# id in target X's sibling .sections.json. Handles relative ../ targets.
# FR-92; spec §14.1.
set -e
FIXTURE=${1:-tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture}
fail=0
for html in $(find "$FIXTURE" -name "*.html" -not -name "index.html"); do
  while IFS=$'\t' read -r target frag; do
    [ -z "$frag" ] && continue
    base_dir=$(dirname "$html")
    if [[ "$target" == */* ]]; then
      tpath="$(cd "$base_dir" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    else
      tpath="$base_dir/$target"
    fi
    sj="${tpath%.html}.sections.json"
    if [ ! -f "$sj" ]; then
      echo "FAIL: $html refs $target → $sj missing"
      fail=1
      continue
    fi
    hit=$(jq -r --arg f "$frag" '.sections[] | select(.id == $f) | .id' "$sj")
    if [ "$hit" != "$frag" ]; then
      echo "FAIL: $html#$frag → $sj has no matching id"
      fail=1
    fi
  done < <(grep -oE 'href="[^"]+\.html#[^"]+"' "$html" | sed -E 's|href="([^#]+)#(.+)"|\1\t\2|')
done
[ $fail -eq 0 ] || exit 1
echo "PASS: assert_cross_doc_anchors.sh"
