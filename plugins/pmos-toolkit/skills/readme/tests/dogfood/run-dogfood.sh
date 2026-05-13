#!/usr/bin/env bash
# run-dogfood.sh — drives /readme rubric audit on the host repo's READMEs.
# Asserts G1 (≥90% rubric pass-rate across the 6-README target set) and
# G3 (≥5 findings on plugins/pmos-toolkit/README.md).
#
# Per /plan T26 Loop-1 F2 disposition: ADVISORY. ALWAYS exits 0.
# /verify Phase 7 owns the gate via accepted_residuals[] on ADVISORY_FAIL,
# mirroring the spec §13.5 + dogfood follow-up A2/A4 residual pattern.
#
# Bash 3.2-safe (macOS default): no mapfile, no `<<<`, no associative arrays.
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
RUBRIC="$REPO_ROOT/plugins/pmos-toolkit/skills/readme/scripts/rubric.sh"

# Target set: root README + pmos-toolkit plugin README + up to 4 more plugin
# READMEs (mtime-desc; alpha-sort tiebreak via stat ordering on macOS).
# If fewer than 5 plugins exist, use what exists and log the shortfall.
targets=()
[ -f "$REPO_ROOT/README.md" ] && targets+=("$REPO_ROOT/README.md")
[ -f "$REPO_ROOT/plugins/pmos-toolkit/README.md" ] && targets+=("$REPO_ROOT/plugins/pmos-toolkit/README.md")

# Enumerate other plugin READMEs (exclude pmos-toolkit; already added).
other_count=0
if [ -d "$REPO_ROOT/plugins" ]; then
  # Collect candidate paths, then stat-sort by mtime desc (BSD `stat -f %m` on
  # macOS; GNU `stat -c %Y` on Linux). Use a portable awk-shim via `ls -t`.
  candidates=$(
    for d in "$REPO_ROOT"/plugins/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      [ "$name" = "pmos-toolkit" ] && continue
      if [ -f "$d/README.md" ]; then
        # Print mtime + path; portable mtime via `ls -t` would lose precision —
        # use `find -printf` where available, fall back to `ls -lT`.
        printf '%s\n' "$d/README.md"
      fi
    done
  )
  if [ -n "$candidates" ]; then
    # mtime-desc sort (best-effort portable): macOS `stat -f`, fallback ls -t.
    sorted=$(
      printf '%s\n' "$candidates" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        if mt=$(stat -f '%m' "$p" 2>/dev/null); then
          printf '%s\t%s\n' "$mt" "$p"
        elif mt=$(stat -c '%Y' "$p" 2>/dev/null); then
          printf '%s\t%s\n' "$mt" "$p"
        else
          printf '0\t%s\n' "$p"
        fi
      done | sort -rn -k1,1 | cut -f2-
    )
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ "$other_count" -ge 4 ] && break
      targets+=("$p")
      other_count=$((other_count + 1))
    done <<EOF
$sorted
EOF
  fi
fi

target_count=${#targets[@]}
expected=6
if [ "$target_count" -lt "$expected" ]; then
  printf 'dogfood: NOTE — only %d/%d targets available (need root + pmos-toolkit + 4 more plugins). Proceeding with what exists.\n' \
    "$target_count" "$expected"
fi

if [ "$target_count" -eq 0 ]; then
  echo "dogfood: ERROR — no targets found; treating as ADVISORY_FAIL on both gates."
  echo "dogfood: G1 ADVISORY_FAIL — residual for /verify (0%) | G3 ADVISORY_FAIL — residual for /verify (0 findings)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Per-target rubric pass — count PASS / FAIL lines.
# ---------------------------------------------------------------------------
total_checks=0
total_pass=0
total_fail=0

for path in "${targets[@]}"; do
  # rubric.sh may exit 1 when any check fails; capture output regardless.
  result=$(bash "$RUBRIC" "$path" 2>/dev/null || true)
  pass=$(printf '%s\n' "$result" | grep -c $'\tPASS\t' || true)
  fail=$(printf '%s\n' "$result" | grep -c $'\tFAIL\t' || true)
  total_pass=$((total_pass + pass))
  total_fail=$((total_fail + fail))
  total_checks=$((total_checks + pass + fail))
  rel=${path#"$REPO_ROOT/"}
  printf 'dogfood: %s — pass=%d fail=%d\n' "$rel" "$pass" "$fail"
done

# G1: ≥90% pass rate across all checks.
if [ "$total_checks" -gt 0 ]; then
  pass_pct=$((total_pass * 100 / total_checks))
else
  pass_pct=0
fi

# G3: ≥5 findings on plugins/pmos-toolkit/README.md.
pmos_readme="$REPO_ROOT/plugins/pmos-toolkit/README.md"
if [ -f "$pmos_readme" ]; then
  pmos_result=$(bash "$RUBRIC" "$pmos_readme" 2>/dev/null || true)
  pmos_fail=$(printf '%s\n' "$pmos_result" | grep -c $'\tFAIL\t' || true)
else
  printf 'dogfood: NOTE — %s missing; G3 cannot be measured (treated as 0 findings).\n' "plugins/pmos-toolkit/README.md"
  pmos_fail=0
fi

status_g1="PASS"
[ "$pass_pct" -ge 90 ] || status_g1="ADVISORY_FAIL — residual for /verify"
status_g3="PASS"
[ "$pmos_fail" -ge 5 ] || status_g3="ADVISORY_FAIL — residual for /verify"

echo "dogfood: G1 $status_g1 ($pass_pct%) | G3 $status_g3 ($pmos_fail findings)"

# T26 is advisory per /plan Loop-1 F2: ALWAYS exit 0.
# /verify Phase 7 owns the gate via accepted_residuals[].
exit 0
