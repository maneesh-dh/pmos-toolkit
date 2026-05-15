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

# 3. Strong-fixture sanity: ≥12/16 checks PASS (rubric.sh selftest threshold).
#    Rubric now has 16 [D] rows after T2's cross-cutting addition.
pass_count=$(grep -c $'\tPASS\t' "$tmp/out1.tsv" || true)
if [ "${pass_count:-0}" -lt 12 ]; then
  echo "FAIL: strong fixture scored ${pass_count}/16 < 12 (rubric.sh selftest gate)"
  cat "$tmp/out1.tsv"
  exit 1
fi

# 4. Cross-cutting [D] check (T2 / FR-08): row must be present in output.
if ! grep -qE '^cross-cutting-capabilities-surfaced\t' "$tmp/out1.tsv"; then
  echo "FAIL: cross-cutting-capabilities-surfaced row missing from audit output"
  exit 1
fi

# 5. BSD-awk fork (T1 / FR-05/FR-06): explicitly force the BSD awk path
#    (macOS /usr/bin/awk) and assert install-or-quickstart-presence PASSes.
if [ -x /usr/bin/awk ]; then
  PATH="/usr/bin:$PATH" bash "$SCRIPTS/rubric.sh" "$tmp/README.md" \
    >"$tmp/out-bsd.tsv" 2>&1 || true
  if ! grep -qE '^install-or-quickstart-presence\tPASS\t' "$tmp/out-bsd.tsv"; then
    echo "FAIL: install-or-quickstart-presence regressed under BSD awk"
    grep '^install-or-quickstart-presence' "$tmp/out-bsd.tsv" || true
    exit 1
  fi
fi

# 6. Audit-mode contract (T6 / FR-15): SKILL.md must declare that audit-mode
#    does NOT fire AskUserQuestion. Grep the spec text for the contract line.
if ! grep -qF 'Do NOT fire `AskUserQuestion`' "$HERE/../../SKILL.md"; then
  echo "FAIL: SKILL.md audit-mode contract missing the 'Do NOT fire AskUserQuestion' clause"
  exit 1
fi

echo "PASS: audit_clean — deterministic eval (${pass_count}/16 PASS), zero file diff (NFR-2 holds), cross-cutting row present, BSD-awk fork green, audit-mode contract preserved"
exit 0
