#!/usr/bin/env bash
set -e
D=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature
test -f "$D/03_plan_defect_T7.md" || { echo "FAIL: defect file not written"; exit 1; }
awk '/^---$/{c++;next} c==1' "$D/03_plan_defect_T7.md" | grep -q '^defect_task: T7' || { echo "FAIL: bad defect frontmatter"; exit 1; }
for sec in '## Failure Context' '## Affected Artifacts' '## Suggested Fix Direction'; do
  grep -qF "$sec" "$D/03_plan_defect_T7.md" || { echo "FAIL: missing section $sec"; exit 1; }
done
echo PASS
