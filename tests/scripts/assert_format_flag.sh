#!/usr/bin/env bash
# Assert: each affected SKILL.md documents the FR-12 output_format contract.
# Static-check harness — see task-18.md "OQ-3 resolution" for why the live
# runtime invocation called for in plan T18 collapses to a static check.
#
# For each skill we require:
#   (a) ≥1 mention of `output_format` (resolution gate present)
#   (b) ≥1 mention of `both` (the both-mode branch is documented)
#   (c) ≥1 mention of `_shared/html-authoring/` (substrate is the authoring path)
#   (d) explicit citation of the cli flag `--format` OR `--format <html|md|both>`
#
# Spec refs: FR-12, FR-80, FR-81; spec §14.2.
# (No `set -e` — grep -c returns non-zero on 0 matches, which we count as data,
# not as a script-fatal error. Explicit fail tracking via $fail.)
SKILLS_ROOT=${1:-plugins/pmos-toolkit/skills}
AFFECTED="requirements spec plan msf-req grill artifact verify simulate-spec msf-wf design-crit"
fail=0
for s in $AFFECTED; do
  f="$SKILLS_ROOT/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "FAIL: $s — SKILL.md not found at $f"
    fail=1
    continue
  fi
  outfmt=$(grep -cE "output_format" "$f")
  both=$(grep -cE '`both`|\|both>|=both|: *both' "$f")
  authoring=$(grep -c "html-authoring" "$f")
  flag=$(grep -cE "\-\-format[[:space:]]+(html|md|both|<)" "$f")
  miss=""
  [ "$outfmt"    -ge 1 ] || miss="$miss output_format"
  [ "$both"      -ge 1 ] || miss="$miss both-branch"
  [ "$authoring" -ge 1 ] || miss="$miss html-authoring"
  [ "$flag"      -ge 1 ] || miss="$miss --format-flag"
  if [ -n "$miss" ]; then
    echo "FAIL: $s — missing:$miss"
    fail=1
  else
    echo "OK:   $s — output_format=$outfmt both=$both authoring=$authoring flag=$flag"
  fi
done
[ $fail -eq 0 ] || exit 1
echo "PASS: assert_format_flag.sh (10 skills)"
