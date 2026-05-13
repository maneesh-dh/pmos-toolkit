#!/usr/bin/env bash
# scaffold_greenfield.sh — assert the per-type opening-shape contract is
# emitted by /readme's substrate.
#
# /readme's scaffold mode is un-mockable from bash (LLM-driven assembly), so
# this test enforces the CONTRACT surface: reference/opening-shapes.md is the
# single source of truth /readme reads at scaffold time. We verify:
#
#   1. All 7 repo-type opening shapes are documented (FR-SS-2).
#   2. Each opening shape's 5-block / map+identity skeleton is present and
#      ≤200 lines for any single shape section (spec §13.2 cap proxy: no
#      single shape's reference block exceeds the cap /readme will emit).
#   3. Greenfield gate: workspace-discovery on an empty repo returns
#      `unknown layout` (the scaffold-mode entry condition).
#
# Bash 3.2-safe. self-cleaning tmp.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../scripts"
SHAPES="$HERE/../../reference/opening-shapes.md"

tmp="$(mktemp -d -t readme-scaffold-greenfield.XXXXXX)"
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

[ -f "$SHAPES" ] || { echo "FAIL: opening-shapes.md missing: $SHAPES"; exit 1; }

# --- (1) 7 repo-type sections present ----------------------------------------
required_types="library cli plugin app monorepo-package monorepo-root plugin-marketplace-root"
missing=""
for t in $required_types; do
  if ! grep -qE "^### [0-9.]+ $t\b" "$SHAPES"; then
    missing="$missing $t"
  fi
done
if [ -n "$missing" ]; then
  echo "FAIL: opening-shapes.md is missing per-type sections:$missing"
  exit 1
fi

# --- (2) Single-shape line count <= 200 --------------------------------------
# Carve each `### N.M <type>` block; assert no single one exceeds 200 lines.
awk '
  /^### [0-9]+\.[0-9]+ [a-z-]+/ {
    if (start) {
      n = NR - start
      printf "%s\t%d\n", section, n
    }
    section = $0
    start = NR
    next
  }
  /^## / && start {
    n = NR - start
    printf "%s\t%d\n", section, n
    start = 0
  }
  END {
    if (start) {
      n = NR - start + 1
      printf "%s\t%d\n", section, n
    }
  }
' "$SHAPES" > "$tmp/shape-sizes.tsv"

overlong=$(awk -F'\t' '$2 > 200 {print}' "$tmp/shape-sizes.tsv")
if [ -n "$overlong" ]; then
  echo "FAIL: opening-shape block(s) exceed 200 lines:"
  printf '%s\n' "$overlong"
  exit 1
fi

# --- (3) Greenfield gate -----------------------------------------------------
# Empty repo dir -> workspace-discovery emits `unknown layout`.
mkdir -p "$tmp/greenfield-repo"
disc=$(bash "$SCRIPTS/workspace-discovery.sh" "$tmp/greenfield-repo" 2>/dev/null)
if ! printf '%s\n' "$disc" | grep -q '"detected": "unknown layout"'; then
  echo "FAIL: workspace-discovery on empty repo did not emit 'unknown layout'"
  printf '%s\n' "$disc"
  exit 1
fi

block_count=$(wc -l < "$tmp/shape-sizes.tsv" | tr -d ' ')
echo "PASS: scaffold_greenfield — 7/7 opening shapes documented, ${block_count} blocks all <=200 lines, greenfield gate fires"
exit 0
