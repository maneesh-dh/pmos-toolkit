#!/usr/bin/env bash
# audit_clean.sh — NFR-2 idempotency contract test.
#
# Asserts that running the audit substrate (rubric.sh) twice against the same
# README produces (a) byte-identical findings TSV output and (b) zero diff on
# the README itself (audit is read-only). This is the contract surface for
# /readme's "audit a /readme-emitted scaffold => zero new findings, zero
# diff" idempotency claim from NFR-2.
#
# Uses a known-strong fixture (rubric.sh selftest's `strong/01` reference)
# plus stubs for any relative-link targets so the links-resolve check resolves
# under the tmp workdir.
#
# Bash 3.2-safe.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../scripts"
FIXTURE="$HERE/../fixtures/rubric/strong/01_hero-line.md"

tmp="$(mktemp -d -t readme-audit-clean.XXXXXX)"
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

[ -f "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }

cp "$FIXTURE" "$tmp/README.md"
cp "$FIXTURE" "$tmp/README.snapshot.md"

# Materialise any relative-link targets the fixture references as empty stubs,
# so the links-resolve check resolves correctly when the fixture is copied out
# of its source tree.
grep -oE '\[[^]]+\]\([^)]+\)' "$tmp/README.md" 2>/dev/null \
  | sed -E 's/.*\(([^)]+)\)/\1/' \
  | grep -v -E '^(https?://|#|mailto:)' \
  | while IFS= read -r lnk; do
      fpath="${lnk%%#*}"
      [ -z "$fpath" ] && continue
      mkdir -p "$tmp/$(dirname "$fpath")" 2>/dev/null || true
      [ -e "$tmp/$fpath" ] || : > "$tmp/$fpath"
    done

# Run rubric twice; capture both outputs.
bash "$SCRIPTS/rubric.sh" "$tmp/README.md" >"$tmp/out1.tsv" 2>&1 || true
bash "$SCRIPTS/rubric.sh" "$tmp/README.md" >"$tmp/out2.tsv" 2>&1 || true

# 1. Byte-identical findings on re-run (deterministic, idempotent eval).
if ! diff -u "$tmp/out1.tsv" "$tmp/out2.tsv" >/dev/null; then
  echo "FAIL: rubric.sh produced non-deterministic output on re-run"
  diff -u "$tmp/out1.tsv" "$tmp/out2.tsv" | head -40
  exit 1
fi

# 2. Zero diff on the README itself (audit is read-only).
if ! diff -u "$tmp/README.snapshot.md" "$tmp/README.md" >/dev/null; then
  echo "FAIL: audit pass mutated the README (NFR-2 idempotency violation)"
  diff -u "$tmp/README.snapshot.md" "$tmp/README.md" | head -40
  exit 1
fi

# 3. Strong-fixture sanity: ≥12/15 checks PASS (matches rubric.sh selftest
#    threshold for "strong-agreement").
pass_count=$(grep -c $'\tPASS\t' "$tmp/out1.tsv" || true)
if [ "${pass_count:-0}" -lt 12 ]; then
  echo "FAIL: strong fixture scored ${pass_count}/15 < 12 (rubric.sh selftest gate)"
  cat "$tmp/out1.tsv"
  exit 1
fi

echo "PASS: audit_clean — deterministic eval (${pass_count}/15 PASS), zero file diff (NFR-2 holds)"
exit 0
