#!/usr/bin/env bash
# Assert: the /survey-design skill is structurally complete and the release
# wiring (manifest sync, README row, CHANGELOG entry) is in place.
# Static checks per 02_spec.html §13.1. This is the "red" check authored in
# plan task T2 — it FAILS until T3-T9 land, then PASSES at TN.
set -u
SKILLDIR=plugins/pmos-toolkit/skills/survey-design
SKILL=$SKILLDIR/SKILL.md
REF_BP=$SKILLDIR/reference/survey-best-practices.md
REF_AP=$SKILLDIR/reference/question-antipatterns.md
REF_PX=$SKILLDIR/reference/platform-export.md
PREVIEW=$SKILLDIR/assets/survey-preview.js
MAN_CC=plugins/pmos-toolkit/.claude-plugin/plugin.json
MAN_CX=plugins/pmos-toolkit/.codex-plugin/plugin.json
fail=0
note() { echo "FAIL: $1"; fail=1; }

# --- skill shell ---
[ -f "$SKILL" ] || note "missing $SKILL"
grep -q '^name: survey-design' "$SKILL" 2>/dev/null || note "$SKILL: missing 'name: survey-design' frontmatter"
# >=5 quoted trigger phrases somewhere in the frontmatter description block.
desc_phrases=$(awk '/^description:/,/^[a-z_-]+:/' "$SKILL" 2>/dev/null | grep -oE '"[^"]+"' | wc -l | tr -d ' ')
[ "${desc_phrases:-0}" -ge 5 ] 2>/dev/null || note "$SKILL: description has <5 quoted trigger phrases (found ${desc_phrases:-0})"
grep -q 'non-interactive-block:start' "$SKILL" 2>/dev/null || note "$SKILL: missing non-interactive-block:start marker"
grep -q 'non-interactive-block:end' "$SKILL" 2>/dev/null || note "$SKILL: missing non-interactive-block:end marker"
grep -qi 'Platform Adaptation' "$SKILL" 2>/dev/null || note "$SKILL: missing 'Platform Adaptation' section"
grep -qi 'Release prerequisites' "$SKILL" 2>/dev/null || note "$SKILL: missing 'Release prerequisites' section"
grep -qi 'Anti-Pattern' "$SKILL" 2>/dev/null || note "$SKILL: missing 'Anti-Patterns' section"
grep -qi 'Capture Learnings' "$SKILL" 2>/dev/null || note "$SKILL: missing 'Capture Learnings' section"
# reference content must NOT be inlined into SKILL.md
! grep -qi 'detection heuristic' "$SKILL" 2>/dev/null || note "$SKILL: looks like reference/* content was inlined (found 'detection heuristic')"

# --- reference files exist and are non-trivial ---
for f in "$REF_BP" "$REF_AP" "$REF_PX"; do
  [ -f "$f" ] || { note "missing $f"; continue; }
  lc=$(wc -l < "$f" | tr -d ' ')
  [ "${lc:-0}" -gt 20 ] || note "$f: too short (${lc:-0} lines)"
done

# --- antipattern catalog id coverage ---
if [ -f "$REF_AP" ]; then
  missing=""
  for id in A1 A2 A3 A4 A5 A6 A7 A8 B1 B2 B3 B4 C1 C2 C3 C4 C5 C6 C7 C8 D1 D2 D3 D4 D5 D6 D7 E1 E2 E3 E4 E5 E6; do
    grep -q "\b$id\b" "$REF_AP" 2>/dev/null || missing="$missing $id"
  done
  [ -z "$missing" ] || note "$REF_AP: missing catalog ids:$missing"
  grep -qi 'detection heuristic' "$REF_AP" 2>/dev/null || note "$REF_AP: missing 'detection heuristic' label"
  dh=$(grep -ci 'detection heuristic' "$REF_AP" 2>/dev/null); dh=${dh:-0}
  [ "$dh" -ge 33 ] 2>/dev/null || note "$REF_AP: expected >=33 'detection heuristic' lines (found $dh)"
fi

# --- platform coverage ---
if [ -f "$REF_PX" ]; then
  grep -qi 'typeform' "$REF_PX" || note "$REF_PX: no Typeform coverage"
  grep -qi 'surveymonkey' "$REF_PX" || note "$REF_PX: no SurveyMonkey coverage"
  grep -qi 'google forms' "$REF_PX" || note "$REF_PX: no Google Forms coverage"
  grep -Eqi 'qsf|qualtrics' "$REF_PX" || note "$REF_PX: no Qualtrics/QSF coverage"
  grep -qi 'downgrade' "$REF_PX" || note "$REF_PX: no downgrade documentation"
fi

# --- survey-preview.js ---
if [ -f "$PREVIEW" ]; then
  ! grep -Eq 'https?://' "$PREVIEW" || note "$PREVIEW: contains http(s):// reference (NFR-02: no CDN/external refs)"
  ! grep -Eq '^[[:space:]]*(import|export)[[:space:]]' "$PREVIEW" || note "$PREVIEW: uses ES module import/export statements (must be a plain <script src>)"
  ! LC_ALL=C grep -qP '[^\x00-\x7F]' "$PREVIEW" 2>/dev/null || note "$PREVIEW: contains non-ASCII bytes (must be ASCII-only)"
  grep -q 'survey-data' "$PREVIEW" || note "$PREVIEW: does not reference the #survey-data element"
  grep -q 'skip_logic' "$PREVIEW" || note "$PREVIEW: does not handle skip_logic"
  for t in single_select multi_select forced_choice_grid rating nps dichotomous open_short open_long ranking matrix constant_sum statement; do
    grep -q "$t" "$PREVIEW" || note "$PREVIEW: missing handling for question type '$t'"
  done
  if command -v node >/dev/null 2>&1; then
    node --check "$PREVIEW" 2>/dev/null || note "$PREVIEW: node --check failed (syntax error)"
  fi
else
  note "missing $PREVIEW"
fi

# --- manifest version sync ---
if [ -f "$MAN_CC" ] && [ -f "$MAN_CX" ]; then
  vcc=$(grep '"version"' "$MAN_CC")
  vcx=$(grep '"version"' "$MAN_CX")
  [ "$vcc" = "$vcx" ] || note "manifest version lines differ: claude='$vcc' codex='$vcx'"
  echo "$vcc" | grep -q '2.36.0' || note "$MAN_CC: version not bumped to 2.36.0 (got '$vcc')"
fi

# --- README + CHANGELOG ---
grep -q 'survey-design' README.md 2>/dev/null || note "README.md: no survey-design row"
grep -q '2.36.0' CHANGELOG.md 2>/dev/null || note "CHANGELOG.md: no 2.36.0 entry"

if [ "$fail" -ne 0 ]; then
  echo "RESULT: assert_survey_design_skill.sh FAILED"
  exit 1
fi
echo "PASS: assert_survey_design_skill.sh"
